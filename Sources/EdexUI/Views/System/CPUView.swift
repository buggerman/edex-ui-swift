import SwiftUI

// Mirrors src/components/system/hardwareInfo/load.tsx
// CPU + GPU usage rows with real-time scrolling charts

struct CPUView: View {
    @Environment(\.edexTheme) var theme
    let cpu: CPUData
    let gpu: GPUData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text("USAGE")
                    .font(.edexMono(size: 11))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(cpu.name)
                        .font(.edexMono(size: 8))
                        .opacity(0.45)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(gpu.name)
                        .font(.edexMono(size: 8))
                        .opacity(0.45)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }

            // CPU row
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.edexMono(size: 9))
                    Text(String(format: "Avg. %.1f%%", cpu.load))
                        .font(.edexMono(size: 8))
                        .opacity(0.45)
                }
                .frame(width: 56, alignment: .leading)

                RealtimeChart(values: cpu.coreUsages, color: theme.textColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .overlay(
                        Rectangle()
                            .stroke(theme.borderColor.opacity(0.2),
                                    style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    )
            }

            // GPU row
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPU")
                        .font(.edexMono(size: 9))
                    Text(gpu.load > 0 ? String(format: "Avg. %.1f%%", gpu.load) : "N/A")
                        .font(.edexMono(size: 8))
                        .opacity(0.45)
                }
                .frame(width: 56, alignment: .leading)

                RealtimeChart(values: [gpu.load], color: theme.textColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .overlay(
                        Rectangle()
                            .stroke(theme.borderColor.opacity(0.2),
                                    style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    )
            }
        }
        .foregroundStyle(theme.textColor)
        .padding(.horizontal, 6)
    }
}
