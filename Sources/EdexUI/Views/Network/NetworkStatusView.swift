import SwiftUI

// Mirrors src/components/network/status/index.tsx

struct NetworkStatusView: View {
    @Environment(\.edexTheme) var theme
    let state: NetworkState
    let ipInfo: IPInfo
    let latency: String

    var stateLabel: String { state == .online ? "ONLINE" : "OFFLINE" }
    var locationLabel: String {
        state == .online
            ? (ipInfo.location.isEmpty ? "UNKNOWN" : ipInfo.location)
            : "DISCONNECTED"
    }
    var ipLabel: String {
        state == .online
            ? (ipInfo.query.isEmpty ? "--.--.--.--" : ipInfo.query)
            : "--.--.--.--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("NETWORK STATUS")
                    .font(.edexMono(size: 11))
                Spacer()
                Text(locationLabel)
                    .font(.edexMono(size: 8))
                    .opacity(0.45)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            HStack(spacing: 0) {
                infoCell(header: "STATE", value: stateLabel)
                infoCell(header: "IPv4",  value: ipLabel)
                infoCell(header: "PING",  value: latency)
            }
        }
        .foregroundStyle(theme.textColor)
        .padding(.horizontal, 6)
    }

    private func infoCell(header: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(header)
                .font(.edexMono(size: 8))
                .opacity(0.45)
            Text(value)
                .font(.edexMono(size: 9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
