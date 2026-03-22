import SwiftUI

// Mirrors src/components/system/ — left panel (16vw wide)
// Stack order mirrors content.tsx: Clock → SysInfo → HardwareInfo → MemInfo → Process

struct SystemPanel: View {
    @Environment(\.edexTheme) var theme
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EdexBanner(title: "PANEL", name: "SYSTEM")

            EdexDivider()

            ClockView()
                .padding(.horizontal, 4)

            EdexDivider()

            SysInfoView(uptime: monitor.data.uptime)

            EdexDivider()

            CPUView(cpu: monitor.data.cpu, gpu: monitor.data.gpu)

            EdexDivider()

            MemoryView(memory: monitor.data.memory, gpu: monitor.data.gpu)

            EdexDivider()

            ProcessListView(processes: monitor.data.processes)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgMain)
    }
}
