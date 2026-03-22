import SwiftUI

// Mirrors src/components/network/traffic/index.tsx
// Dual-axis chart: upload above centre, download below

struct NetworkTrafficView: View {
    @Environment(\.edexTheme) var theme
    let traffic: NetworkTraffic
    let state: NetworkState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("TRAFFIC")
                    .font(.edexMono(size: 11))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 7))
                        Text(traffic.transmitRate.prettyBytes + "/s")
                            .font(.edexMono(size: 8))
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 7))
                        Text(traffic.receiveRate.prettyBytes + "/s")
                            .font(.edexMono(size: 8))
                    }
                }
                .opacity(0.7)
            }

            NetworkChart(
                uploadRate:   traffic.transmitRate,
                downloadRate: traffic.receiveRate,
                color: theme.textColor
            )
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                Rectangle()
                    .stroke(theme.borderColor.opacity(0.2),
                            style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
            )
        }
        .foregroundStyle(theme.textColor)
        .padding(.horizontal, 6)
    }
}
