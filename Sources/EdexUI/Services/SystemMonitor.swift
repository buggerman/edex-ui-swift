import Foundation
import Darwin
import Metal

// Mirrors src-tauri/src/sys/main.rs — polls at 1 Hz and publishes SystemData

@MainActor
final class SystemMonitor: ObservableObject {
    @Published var data = SystemData()
    @Published var disks: [DiskInfo] = []

    private var timer: Timer?

    // CPU tick tracking for delta-based % calculation
    private var prevCPUInfo: processor_info_array_t?
    private var prevNumCPUInfo: mach_msg_type_number_t = 0

    // Network is owned by NetworkMonitor; this class handles system only.

    func start() {
        fetchGPUName()
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func poll() {
        var snapshot = SystemData()
        snapshot.uptime = uptime()
        snapshot.cpu    = cpuData()
        snapshot.memory = memoryData()
        snapshot.gpu    = gpuSnapshot()
        snapshot.processes = topProcesses()
        data = snapshot
        disks = diskData()
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
    // Uses host_processor_info for per-core tick deltas — same approach as the Rust sysinfo crate
    private func cpuData() -> CPUData {
        var numCPU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPU, &cpuInfo, &numCpuInfo) == KERN_SUCCESS,
              let cpuInfo else {
            return CPUData()
        }

        var coreUsages: [Double] = []
        let prevInfo = prevCPUInfo
        let prevCount = prevNumCPUInfo

        for i in 0..<Int(numCPU) {
            let base = Int(CPU_STATE_MAX) * i
            let user   = cpuInfo[base + Int(CPU_STATE_USER)]
            let sys    = cpuInfo[base + Int(CPU_STATE_SYSTEM)]
            let idle   = cpuInfo[base + Int(CPU_STATE_IDLE)]
            let nice   = cpuInfo[base + Int(CPU_STATE_NICE)]

            var usage: Double = 0
            if let prev = prevInfo, Int(prevCount) > base + Int(CPU_STATE_NICE) {
                let dUser = user - prev[base + Int(CPU_STATE_USER)]
                let dSys  = sys  - prev[base + Int(CPU_STATE_SYSTEM)]
                let dIdle = idle - prev[base + Int(CPU_STATE_IDLE)]
                let dNice = nice - prev[base + Int(CPU_STATE_NICE)]
                let total = Double(dUser + dSys + dIdle + dNice)
                let used  = Double(dUser + dSys + dNice)
                if total > 0 { usage = (used / total) * 100 }
            }
            coreUsages.append(usage)
        }

        // Free previous info
        if let prev = prevCPUInfo {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: prev),
                          vm_size_t(Int(prevNumCPUInfo) * MemoryLayout<integer_t>.stride))
        }
        prevCPUInfo = cpuInfo
        prevNumCPUInfo = numCpuInfo

        let avgLoad = coreUsages.isEmpty ? 0 : coreUsages.reduce(0, +) / Double(coreUsages.count)

        var nameBuffer = [CChar](repeating: 0, count: 256)
        var nameSize = nameBuffer.count
        sysctlbyname("machdep.cpu.brand_string", &nameBuffer, &nameSize, nil, 0)
        let cpuName = String(cString: nameBuffer)

        return CPUData(
            name: cpuName.isEmpty ? "Apple Silicon" : cpuName,
            coreCount: Int(numCPU),
            load: avgLoad,
            coreUsages: coreUsages,
            temperature: 0   // No public API on Apple Silicon
        )
    }

    // MARK: Memory
    // vm_statistics64 mirrors what the Rust sysinfo crate reads
    private func memoryData() -> MemoryInfo {
        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                _ = host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &count)
            }
        }

        let pageSize = UInt64(vm_page_size)
        var totalMem: UInt64 = 0
        var sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMem, &sz, nil, 0)

        // Swap via sysctl xsw_usage
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)

        return MemoryInfo(
            total:       totalMem,
            active:      UInt64(vmStats.active_count)     * pageSize,
            inactive:    UInt64(vmStats.inactive_count)   * pageSize,
            wired:       UInt64(vmStats.wire_count)       * pageSize,
            compressed:  UInt64(vmStats.compressor_page_count) * pageSize,
            free:        UInt64(vmStats.free_count)       * pageSize,
            swapUsed:    swapUsage.xsu_used,
            swapTotal:   swapUsage.xsu_total
        )
    }

    // MARK: GPU
    // On Apple Silicon, Metal gives us the device name.
    // Load % and temperature are not available via public APIs (no nvml, no SMC access).
    // recommendedMaxWorkingSetSize approximates the VRAM budget.
    private var gpuName: String = ""

    private func fetchGPUName() {
        if let device = MTLCreateSystemDefaultDevice() {
            gpuName = device.name
        }
    }

    private func gpuSnapshot() -> GPUData {
        guard let device = MTLCreateSystemDefaultDevice() else { return GPUData() }
        let budget = Int64(device.recommendedMaxWorkingSetSize)
        // currentAllocatedSize is the best public proxy for VRAM usage
        let used = Int64(device.currentAllocatedSize)
        let usagePct = budget > 0 ? Double(used) / Double(budget) * 100 : 0
        return GPUData(
            name: device.name,
            load: 0,         // not available
            usedMemory: used,
            totalMemory: budget,
            memoryUsage: usagePct,
            temperature: 0   // not available
        )
    }

    // MARK: Processes
    // Run `ps` to get top-10 processes by CPU — mirrors the Rust sysinfo process collection
    private func topProcesses() -> [ProcInfo] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-eo", "pid,pcpu,pmem,stat,comm", "-r"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8) ?? ""
        var results: [ProcInfo] = []
        let lines = output.components(separatedBy: "\n").dropFirst() // skip header
        for line in lines.prefix(15) {
            let parts = line.trimmingCharacters(in: .whitespaces)
                            .components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
            guard parts.count >= 5,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2]) else { continue }
            let state = parts[3]
            let comm = parts[4...].joined(separator: " ")
            let name = (comm as NSString).lastPathComponent
            results.append(ProcInfo(id: pid, name: name, cpuUsage: cpu,
                                       memUsage: mem, state: state))
        }
        return results
    }

    // MARK: Disks
    // Mirrors DiskUsage from Rust — uses FileManager volumeURLs
    private func diskData() -> [DiskInfo] {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeNameKey,
                .volumeIsInternalKey,
                .volumeIsRemovableKey,
            ],
            options: [.skipHiddenVolumes]
        ) else { return [] }

        return urls.compactMap { url in
            guard let vals = try? url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeNameKey,
                .volumeIsInternalKey,
            ]) else { return nil }

            let total     = Int64(vals.volumeTotalCapacity ?? 0)
            let available = Int64(vals.volumeAvailableCapacityForImportantUsage ?? 0)
            guard total > 0 else { return nil }

            let used = total - available
            let usagePct = Double(used) / Double(total) * 100
            let name = vals.volumeName ?? url.lastPathComponent
            let isInternal = vals.volumeIsInternal ?? false

            return DiskInfo(id: url.path, name: name, isInternal: isInternal,
                            total: total, available: available, usagePercent: usagePct)
        }
    }
}
