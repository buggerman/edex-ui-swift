import SwiftUI

// Mirrors src/components/network/ — right panel (16vw wide)
// Stack order mirrors content.tsx: Status → Traffic → DiskUsage

struct NetworkPanel: View {
    @Environment(\.edexTheme) var theme
    @ObservedObject var networkMonitor: NetworkMonitor
    @ObservedObject var systemMonitor: SystemMonitor

    @State private var ipInfo = IPInfo()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EdexBanner(title: "PANEL", name: "NETWORK")

            EdexDivider()

            NetworkStatusView(
                state:   networkMonitor.state,
                ipInfo:  ipInfo,
                latency: networkMonitor.latency
            )

            EdexDivider()

            NetworkTrafficView(
                traffic: networkMonitor.traffic,
                state:   networkMonitor.state
            )

            EdexDivider()

            DiskUsageView(disks: systemMonitor.disks)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgMain)
        .task {
            ipInfo = await IPInfoService.shared.fetch()
        }
        .onChange(of: networkMonitor.state) { _, newState in
            if newState == .online {
                Task { ipInfo = await IPInfoService.shared.fetch() }
            }
        }
    }
}
