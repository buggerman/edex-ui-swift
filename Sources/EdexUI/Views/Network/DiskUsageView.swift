import SwiftUI

// Mirrors src/components/network/disk/index.tsx
// Each disk shown as a label row with a background gradient fill proportional to usage %

struct DiskUsageView: View {
    @Environment(\.edexTheme) var theme
    let disks: [DiskInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DISK USAGE")
                .font(.edexMono(size: 11))
                .foregroundStyle(theme.textColor)
                .padding(.horizontal, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(disks) { disk in
                        DiskRow(disk: disk, theme: theme)
                    }
                }
            }
        }
        .foregroundStyle(theme.textColor)
    }
}

// MARK: - Individual disk row

private struct DiskRow: View {
    let disk: DiskInfo
    let theme: EdexTheme

    var body: some View {
        // GeometryReader is not needed — LinearGradient stops are fractional (0–1)
        // and naturally fill the container width. Using it as a .background avoids
        // the zero-height collapse that occurred inside ScrollView > VStack.
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline) {
                Text(disk.name)
                    .font(.edexMono(size: 10))
                Spacer()
                Text(disk.isInternal ? "Internal" : "External")
                    .font(.edexMono(size: 8))
                    .opacity(0.5)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(disk.total.prettyBytes)
                    .font(.edexMono(size: 8))
                    .opacity(0.7)
                Spacer()
                Text("\(disk.available.prettyBytes) Free")
                    .font(.edexMono(size: 8))
                    .opacity(0.5)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                stops: [
                    .init(color: theme.bgActive.opacity(0.18), location: 0),
                    .init(color: theme.bgActive.opacity(0.18), location: CGFloat(disk.usagePercent / 100)),
                    .init(color: .clear, location: min(CGFloat(disk.usagePercent / 100) + 0.05, 1)),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .animation(.easeInOut(duration: 0.5), value: disk.usagePercent)
    }
}
