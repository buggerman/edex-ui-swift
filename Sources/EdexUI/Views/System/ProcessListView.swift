import SwiftUI

// Mirrors src/components/system/process/index.tsx
// Top processes table with expandable full-list modal

struct ProcessListView: View {
    @Environment(\.edexTheme) var theme
    let processes: [ProcInfo]
    @State private var showModal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row
            HStack(spacing: 0) {
                Text("PROCESSES")
                    .font(.edexMono(size: 11))
                Spacer()
                Button("ALL") {
                    showModal = true
                }
                .font(.edexMono(size: 8))
                .foregroundStyle(theme.textColor.opacity(0.45))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)

            // Top 5 processes
            processHeader
            ForEach(processes.prefix(5)) { proc in
                processRow(proc)
            }
        }
        .foregroundStyle(theme.textColor)
        .sheet(isPresented: $showModal) {
            ProcessModalView(processes: processes, theme: theme)
        }
    }

    private var processHeader: some View {
        HStack(spacing: 0) {
            Text("PID")
                .frame(width: 36, alignment: .leading)
            Text("NAME")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU%")
                .frame(width: 36, alignment: .trailing)
            Text("MEM%")
                .frame(width: 36, alignment: .trailing)
        }
        .font(.edexMono(size: 7))
        .opacity(0.45)
        .padding(.horizontal, 6)
    }

    private func processRow(_ proc: ProcInfo) -> some View {
        HStack(spacing: 0) {
            Text("\(proc.id)")
                .frame(width: 36, alignment: .leading)
            Text(proc.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(String(format: "%.1f", proc.cpuUsage))
                .frame(width: 36, alignment: .trailing)
            Text(String(format: "%.1f", proc.memUsage))
                .frame(width: 36, alignment: .trailing)
        }
        .font(.edexMono(size: 8))
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
    }
}

// MARK: - Full process list modal

struct ProcessModalView: View {
    let processes: [ProcInfo]
    let theme: EdexTheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("ACTIVE PROCESSES")
                    .font(.edexMono(size: 13))
                Spacer()
                Button("CLOSE") { dismiss() }
                    .font(.edexMono(size: 10))
                    .foregroundStyle(theme.textColor.opacity(0.6))
                    .buttonStyle(.plain)
            }
            .foregroundStyle(theme.textColor)
            .padding(12)
            .background(theme.bgSecondary)

            Divider().overlay(theme.borderColor.opacity(0.3))

            // Column headers
            HStack(spacing: 0) {
                Text("PID")  .frame(width: 52, alignment: .leading)
                Text("NAME") .frame(maxWidth: .infinity, alignment: .leading)
                Text("CPU%") .frame(width: 52, alignment: .trailing)
                Text("MEM%") .frame(width: 52, alignment: .trailing)
                Text("STATE").frame(width: 44, alignment: .trailing)
            }
            .font(.edexMono(size: 9))
            .foregroundStyle(theme.textColor.opacity(0.45))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(theme.bgSecondary)

            Divider().overlay(theme.borderColor.opacity(0.3))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(processes) { proc in
                        HStack(spacing: 0) {
                            Text("\(proc.id)")
                                .frame(width: 52, alignment: .leading)
                            Text(proc.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(String(format: "%.1f", proc.cpuUsage))
                                .frame(width: 52, alignment: .trailing)
                            Text(String(format: "%.1f", proc.memUsage))
                                .frame(width: 52, alignment: .trailing)
                            Text(proc.state)
                                .frame(width: 44, alignment: .trailing)
                                .opacity(0.5)
                        }
                        .font(.edexMono(size: 9))
                        .foregroundStyle(theme.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)

                        Divider().overlay(theme.borderColor.opacity(0.1))
                    }
                }
            }
            .background(theme.bgMain)
        }
        .background(theme.bgMain)
        .frame(width: 540, height: 480)
        .augmentedPanel(theme, clipSize: 12, corners: [.topLeft, .bottomRight], lineWidth: 1)
    }
}
