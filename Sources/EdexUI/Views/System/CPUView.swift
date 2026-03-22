import SwiftUI

// Matches the Rust project screenshots:
//   CPU USAGE  [Intel® Core™ i7-9750H / GPU name]
//   #1-6   [line chart — 6 overlaid core lines]
//   #7-12  [line chart]
//   CPU       GPU       BATTERY
//   85.2°C    56.9°C    34.5°C

struct CPUView: View {
    @Environment(\.edexTheme) var theme
    let cpu: CPUData
    let gpu: GPUData

    private let groupSize = 6

    private var coreGroups: [[Double]] {
        guard !cpu.coreUsages.isEmpty else { return [] }
        return stride(from: 0, to: cpu.coreUsages.count, by: groupSize).map { start in
            Array(cpu.coreUsages[start ..< min(start + groupSize, cpu.coreUsages.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section header + hardware names
            HStack(alignment: .firstTextBaseline) {
                Text("CPU USAGE")
                    .font(.edexMono(size: 10))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(cpu.name)
                        .font(.edexMono(size: 7)).opacity(0.45).lineLimit(1).minimumScaleFactor(0.5)
                    if !gpu.name.isEmpty {
                        Text(gpu.name)
                            .font(.edexMono(size: 7)).opacity(0.45).lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
            }

            // One chart per group of 6 cores
            ForEach(coreGroups.indices, id: \.self) { gi in
                let group = coreGroups[gi]
                let first = gi * groupSize + 1
                let last  = first + group.count - 1
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(first)-\(last)")
                        .font(.edexMono(size: 8)).opacity(0.5)
                    RealtimeChart(values: group, color: theme.textColor)
                        .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 32)
                        .overlay(
                            Rectangle()
                                .stroke(theme.borderColor.opacity(0.2),
                                        style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        )
                }
            }

            // Fallback if no per-core data: show overall CPU + GPU charts
            if coreGroups.isEmpty {
                cpuGpuFallback
            }

            // Temperature row — CPU / GPU / BATTERY
            HStack(spacing: 0) {
                tempCell("CPU",  cpu.temperature > 0 ? String(format: "%.1f°C", cpu.temperature) : "N/A")
                tempCell("GPU",  gpu.temperature > 0 ? String(format: "%.1f°C", gpu.temperature) : "N/A")
                tempCell("BATT", batteryTemperature)
            }
            .padding(.top, 2)
        }
        .foregroundStyle(theme.textColor)
        .padding(.horizontal, 6)
    }

    // MARK: - Fallback (shows when coreUsages is empty)

    private var cpuGpuFallback: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("CPU").font(.edexMono(size: 8))
                    Text(String(format: "Avg. %.1f%%", cpu.load)).font(.edexMono(size: 7)).opacity(0.45)
                }
                .frame(width: 50, alignment: .leading)
                RealtimeChart(values: cpu.coreUsages.isEmpty ? [cpu.load] : cpu.coreUsages, color: theme.textColor)
                    .frame(maxWidth: .infinity).frame(height: 28)
            }
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("GPU").font(.edexMono(size: 8))
                    Text(gpu.load > 0 ? String(format: "Avg. %.1f%%", gpu.load) : "N/A")
                        .font(.edexMono(size: 7)).opacity(0.45)
                }
                .frame(width: 50, alignment: .leading)
                RealtimeChart(values: [gpu.load], color: theme.textColor)
                    .frame(maxWidth: .infinity).frame(height: 28)
            }
        }
    }

    // MARK: - Helpers

    private func tempCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.edexMono(size: 8)).opacity(0.45)
            Text(value).font(.edexMono(size: 9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Battery temperature via IOKit — not available on Apple Silicon via public API
    private var batteryTemperature: String { "N/A" }
}
