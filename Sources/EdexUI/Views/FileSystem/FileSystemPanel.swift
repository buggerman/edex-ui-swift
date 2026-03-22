import SwiftUI
import AppKit

// Mirrors src/components/filesystem/index.tsx — bottom panel (38vh tall)
// Auto-fill grid of square tiles. Clicking dirs sends `cd` to the active terminal via AppleScript/PTY.

struct FileSystemPanel: View {
    @Environment(\.edexTheme) var theme
    @ObservedObject var fileWatcher: FileWatcher
    @State private var showSettings = false

    // Callback to write a command into the active terminal session
    var sendToTerminal: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            EdexBanner(title: "FILESYSTEM", name: fileWatcher.currentPath)

            // Adaptive tile grid — mirrors grid-cols-[repeat(auto-fill,minmax(8.5vh,1fr))]
            GeometryReader { geo in
                let tileSize = geo.size.height * 0.75
                let cols = max(1, Int(geo.size.width / (tileSize + 4)))

                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 4), count: cols),
                        spacing: 4
                    ) {
                        ForEach(fileWatcher.entries) { entry in
                            FileTileView(entry: entry) { tapped in
                                handleTap(tapped)
                            }
                            .frame(width: tileSize, height: tileSize)
                        }
                    }
                    .padding(4)
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

    // MARK: - Tile tap handling

    private func handleTap(_ entry: FileEntry) {
        switch entry.kind {
        case .settings:
            showSettings = true

        case .backward:
            let parent = URL(fileURLWithPath: fileWatcher.currentPath)
                            .deletingLastPathComponent().path
            sendToTerminal?("cd \(shellEscape(parent))\n")

        case .directory:
            sendToTerminal?("cd \(shellEscape(entry.path))\n")

        case .file, .symlink:
            // Open in default app — mirrors `opener` plugin in Tauri version
            NSWorkspace.shared.open(URL(fileURLWithPath: entry.path))
        }
    }

    private func shellEscape(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
