import SwiftUI

// Mirrors src/components/system/meminfo/index.tsx
// 440-cell grid (40 × 11) + swap bar + VRAM bar

struct MemoryView: View {
    @Environment(\.edexTheme) var theme
    let memory: MemoryInfo
    let gpu: GPUData

    private let cols = 40
    private let rows = 11
    private var totalCells: Int { cols * rows }

    // Cell opacity mirrors the JS opacity classes: opacity-100 / opacity-50 / opacity-25
    private func cellOpacity(index: Int) -> Double {
        let wiredEnd   = memory.wiredCells
        let activeEnd  = wiredEnd + memory.activeCells
        if index < wiredEnd  { return 1.0 }
        if index < activeEnd { return 0.5 }
        return 0.2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("MEMORY")
                    .font(.edexMono(size: 11))
                Spacer()
                Text("USING \(memory.used.prettyBytes) OUT OF \(memory.total.prettyBytes)")
                    .font(.edexMono(size: 7))
                    .opacity(0.45)
                    .lineLimit(1)
            }

            // 440-cell grid
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<cols, id: \.self) { col in
                            let idx = row * cols + col
                            Rectangle()
                                .fill(theme.bgActive.opacity(cellOpacity(index: idx)))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(CGFloat(cols) / CGFloat(rows), contentMode: .fit)

            // Swap bar
            HStack(alignment: .center, spacing: 4) {
                Text("SWAP")
                    .font(.edexMono(size: 9))
                    .frame(width: 32, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(theme.bgActive.opacity(0.15))
                        Rectangle()
                            .fill(theme.bgActive.opacity(0.6))
                            .frame(width: geo.size.width * CGFloat(memory.swapRatio / 100))
                            .animation(.easeInOut(duration: 0.5), value: memory.swapRatio)
                    }
                }
                .frame(height: 6)
                Text(memory.swapUsed.prettyBytes)
                    .font(.edexMono(size: 7))
                    .opacity(0.45)
                    .frame(width: 48, alignment: .trailing)
            }

            Divider()
                .overlay(theme.borderColor.opacity(0.2))

            // VRAM section
            HStack(alignment: .firstTextBaseline) {
                Text("VRAM")
                    .font(.edexMono(size: 10))
                Spacer()
                Text("USING \(gpu.usedMemory.prettyBytes) OUT OF \(gpu.totalMemory.prettyBytes)")
                    .font(.edexMono(size: 7))
                    .opacity(0.45)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(theme.bgActive.opacity(0.15))
                        Rectangle()
                            .fill(theme.bgActive.opacity(0.6))
                            .frame(width: geo.size.width * CGFloat(gpu.memoryUsage / 100))
                            .animation(.easeInOut(duration: 0.5), value: gpu.memoryUsage)
                    }
                }
                .frame(height: 6)
                Text(gpu.usedMemory.prettyBytes)
                    .font(.edexMono(size: 7))
                    .opacity(0.45)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .foregroundStyle(theme.textColor)
        .padding(.horizontal, 6)
    }
}
