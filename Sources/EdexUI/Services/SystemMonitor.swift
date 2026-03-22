import Foundation
import Darwin
import Metal

// MARK: - SystemMonitor
// Thin @MainActor shell: owns @Published state and the 1 Hz timer.
// All blocking work is delegated to SystemPoller and runs on a background thread.

@MainActor
final class SystemMonitor: ObservableObject {
    @Published var data  = SystemData()
    @Published var disks = [DiskInfo]()

    private var timer: Timer?
    private let poller = SystemPoller()

    func start() {
        // First poll in a Task so we don't block the SwiftUI layout pass
        Task { await refresh() }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() async {
        // Task.detached escapes the MainActor — waitUntilExit() no longer blocks the UI
        let (snapshot, diskSnapshot) = await Task.detached(priority: .utility) {
            [poller = self.poller] in poller.collect()
        }.value
        data  = snapshot
        disks = diskSnapshot
    }
}

// MARK: - SystemPoller
// Non-isolated, @unchecked Sendable: owns all mutable polling state.
// Protected by NSLock so it can be called from a detached task safely.

final class SystemPoller: @unchecked Sendable {

    private let lock = NSLock()

    // CPU delta tracking
    private var prevCPUInfo: processor_info_array_t?
    private var prevNumCPUInfo: mach_msg_type_number_t = 0

    // Metal device created once — MTLCreateSystemDefaultDevice() is expensive
    private let metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()

    // CPU brand string read once
    private let cpuBrandString: String = {
        var buf = [CChar](repeating: 0, count: 256)
        var size = buf.count
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        let s = String(cString: buf)
        return s.isEmpty ? "Apple Silicon" : s
    }()

    func collect() -> (SystemData, [DiskInfo]) {
        lock.lock()
        defer { lock.unlock() }

        var s = SystemData()
        s.uptime    = uptime()
        s.cpu       = cpuData()
        s.memory    = memoryData()
        s.gpu       = gpuSnapshot()
        s.processes = topProcesses()
        return (s, diskData())
    }

    // MARK: Uptime

    private func uptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        sysctlbyname("kern.boottime", &boottime, &size, nil, 0)
        let boot = Double(boottime.tv_sec) + Double(boottime.tv_usec) / 1_000_000
        return Date().timeIntervalSince1970 - boot
    }

    // MARK: CPU
    // Delta between successive host_processor_info snapshots gives per-core %

    private func cpuData() -> CPUData {
        var numCPU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPU, &cpuInfo, &numCpuInfo) == KERN_SUCCESS,
              let cpuInfo else { return CPUData() }

        var coreUsages: [Double] = []
        for i in 0..<Int(numCPU) {
            let base = Int(CPU_STATE_MAX) * i
            let user = cpuInfo[base + Int(CPU_STATE_USER)]
            let sys  = cpuInfo[base + Int(CPU_STATE_SYSTEM)]
            let idle = cpuInfo[base + Int(CPU_STATE_IDLE)]
            let nice = cpuInfo[base + Int(CPU_STATE_NICE)]

            var usage: Double = 0
            if let prev = prevCPUInfo, Int(prevNumCPUInfo) > base + Int(CPU_STATE_NICE) {
                let dUser = user - prev[base + Int(CPU_STATE_USER)]
                let dSys  = sys  - prev[base + Int(CPU_STATE_SYSTEM)]
                let dIdle = idle - prev[base + Int(CPU_STATE_IDLE)]
                let dNice = nice - prev[base + Int(CPU_STATE_NICE)]
                let total = Double(dUser + dSys + dIdle + dNice)
                let used  = Double(dUser + dSys + dNice)
                if total > 0 { usage = used / total * 100 }
            }
            coreUsages.append(usage)
        }

        if let prev = prevCPUInfo {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: prev),
                          vm_size_t(Int(prevNumCPUInfo) * MemoryLayout<integer_t>.stride))
        }
        prevCPUInfo    = cpuInfo
        prevNumCPUInfo = numCpuInfo

        let avg = coreUsages.isEmpty ? 0 : coreUsages.reduce(0, +) / Double(coreUsages.count)
        return CPUData(name: cpuBrandString, coreCount: Int(numCPU),
                       load: avg, coreUsages: coreUsages, temperature: 0)
    }

    // MARK: Memory

    private func memoryData() -> MemoryInfo {
        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                _ = host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &count)
            }
        }

        let pageSize = UInt64(vm_page_size)
        var totalMem: UInt64 = 0
        var sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMem, &sz, nil, 0)

        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)

        return MemoryInfo(
            total:      totalMem,
            active:     UInt64(vmStats.active_count)          * pageSize,
            inactive:   UInt64(vmStats.inactive_count)        * pageSize,
            wired:      UInt64(vmStats.wire_count)            * pageSize,
            compressed: UInt64(vmStats.compressor_page_count) * pageSize,
            free:       UInt64(vmStats.free_count)            * pageSize,
            swapUsed:   swapUsage.xsu_used,
            swapTotal:  swapUsage.xsu_total
        )
    }

    // MARK: GPU

    private func gpuSnapshot() -> GPUData {
        guard let device = metalDevice else { return GPUData() }
        let budget = Int64(device.recommendedMaxWorkingSetSize)
        let used   = Int64(device.currentAllocatedSize)
        let pct    = budget > 0 ? Double(used) / Double(budget) * 100 : 0
        return GPUData(name: device.name, load: 0,
                       usedMemory: used, totalMemory: budget,
                       memoryUsage: pct, temperature: 0)
    }

    // MARK: Processes
    // waitUntilExit() is fine here — this method runs on a background thread

    private func topProcesses() -> [ProcInfo] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-eo", "pid,pcpu,pmem,stat,comm", "-r"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        try? proc.run()
        proc.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8) ?? ""
        var results: [ProcInfo] = []
        for line in output.components(separatedBy: "\n").dropFirst().prefix(15) {
            let parts = line.trimmingCharacters(in: .whitespaces)
                            .components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
            guard parts.count >= 5,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2]) else { continue }
            let name = (parts[4...].joined(separator: " ") as NSString).lastPathComponent
            results.append(ProcInfo(id: pid, name: name, cpuUsage: cpu,
                                    memUsage: mem, state: parts[3]))
        }
        return results
    }

    // MARK: Disks

    private func diskData() -> [DiskInfo] {
        let keys: [URLResourceKey] = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeNameKey,
            .volumeIsInternalKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]
        ) else { return [] }

        return urls.compactMap { url in
            guard let vals = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let total     = Int64(vals.volumeTotalCapacity ?? 0)
            let available = Int64(vals.volumeAvailableCapacityForImportantUsage ?? 0)
            guard total > 0 else { return nil }
            let pct  = Double(total - available) / Double(total) * 100
            let name = vals.volumeName ?? url.lastPathComponent
            return DiskInfo(id: url.path, name: name,
                            isInternal: vals.volumeIsInternal ?? false,
                            total: total, available: available, usagePercent: pct)
        }
    }
}
