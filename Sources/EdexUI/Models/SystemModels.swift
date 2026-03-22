import Foundation

// Mirrors SystemData / CpuUsage / GpuUsage / MemoryInfo / ProcessInfo from src-tauri/src/sys/main.rs

struct SystemData {
    var uptime: TimeInterval = 0
    var cpu: CPUData = CPUData()
    var gpu: GPUData = GPUData()
    var memory: MemoryInfo = MemoryInfo()
    var processes: [ProcInfo] = []
}

struct CPUData {
    var name: String = "UNKNOWN"
    var coreCount: Int = 0
    var load: Double = 0          // overall average %
    var coreUsages: [Double] = [] // per-core % (0-100)
    var temperature: Double = 0   // °C (not available on Apple Silicon via public API)
}

struct GPUData {
    var name: String = ""
    var load: Double = 0          // not available on Apple Silicon via public API
    var usedMemory: Int64 = 0     // bytes
    var totalMemory: Int64 = 0    // bytes
    var memoryUsage: Double = 0   // 0-100 %
    var temperature: Double = 0   // not available on Apple Silicon via public API
}

struct MemoryInfo {
    // Raw values in bytes
    var total: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var free: UInt64 = 0

    var used: UInt64 { active + wired + compressed }
    var available: UInt64 { inactive + free }

    // Swap
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
    var swapRatio: Double { swapTotal > 0 ? Double(swapUsed) / Double(swapTotal) * 100 : 0 }

    // For the 440-cell memory grid (mirrors Rust MEMORY_BAR_WIDTH = 440)
    static let gridSize: Int = 440
    var activeCells: Int  { total > 0 ? Int(Double(active)             / Double(total) * 440) : 0 }
    var wiredCells: Int   { total > 0 ? Int(Double(wired + compressed) / Double(total) * 440) : 0 }
    var availableCells: Int { total > 0 ? Int(Double(available)        / Double(total) * 440) : 0 }
}

// Named ProcInfo to avoid collision with Foundation.ProcessInfo
struct ProcInfo: Identifiable {
    let id: Int32       // pid
    var name: String
    var cpuUsage: Double   // %
    var memUsage: Double   // %
    var state: String
}

struct DiskInfo: Identifiable, Equatable {
    let id: String      // mount point path
    var name: String
    var isInternal: Bool
    var total: Int64    // bytes
    var available: Int64 // bytes
    var usagePercent: Double // 0-100
}
