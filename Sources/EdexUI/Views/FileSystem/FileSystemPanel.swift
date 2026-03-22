import SwiftUI
import AppKit

struct FileSystemPanel: View {
    @Environment(\.edexTheme) var theme
    @ObservedObject var fileWatcher: FileWatcher
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            EdexBanner(title: "FILESYSTEM", name: fileWatcher.currentPath)

            GeometryReader { geo in
                let screenHeight = NSScreen.main?.frame.height ?? geo.size.height / 0.38
                let tileSize = (screenHeight * 0.085).rounded()
                let cols = max(1, Int(geo.size.width / (tileSize + 2)))

                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 2), count: cols),
                        spacing: 2
                    ) {
                        ForEach(fileWatcher.entries) { entry in
                            FileTileView(entry: entry) { tapped in
                                handleTap(tapped)
                            }
                            .frame(width: tileSize, height: tileSize)
                        }
                    }
                    .padding(2)
                }
            }
        }
        .background(theme.bgMain)
        .sheet(isPresented: $showSettings) {
            SettingsView(showHidden: fileWatcher.showHidden) { newHidden in
                fileWatcher.showHidden = newHidden
            }
        }
    }

    private func handleTap(_ entry: FileEntry) {
        switch entry.kind {
        case .settings:
            showSettings = true

        case .backward:
            let parent = URL(fileURLWithPath: fileWatcher.currentPath)
                            .deletingLastPathComponent().path
            // Use fileWatcher.sendToTerminal — wired to the active PTY by TerminalPanel
            fileWatcher.sendToTerminal?("cd \(shellEscape(parent))\n")
            fileWatcher.updateCWD(parent)

        case .directory:
            fileWatcher.sendToTerminal?("cd \(shellEscape(entry.path))\n")
            fileWatcher.updateCWD(entry.path)

        case .file, .symlink:
            NSWorkspace.shared.open(URL(fileURLWithPath: entry.path))
        }
    }

    private func shellEscape(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
