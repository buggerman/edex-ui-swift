import SwiftUI

// Root layout — mirrors App.tsx + proportions from index.css / App.tsx:
//   Top row:  System (16vw) | Terminal (68vw) | Network (16vw)  — 70vh tall
//   Bottom:   FileSystem | optional keyboard (side by side)      — 30vh tall
//
// When the keyboard is visible it sits to the right of the filesystem panel,
// taking a fixed width so the file grid shrinks horizontally rather than
// splitting the vertical space.

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("showKeyboard") private var showKeyboard = false

    @StateObject private var sysMonitor  = SystemMonitor()
    @StateObject private var netMonitor  = NetworkMonitor()
    @StateObject private var fileWatcher = FileWatcher()

    // Keyboard takes ~57% of bottom width (matches original eDEX-UI proportions)
    // Filesystem gets the remaining ~43%
    private func keyboardWidth(for totalWidth: CGFloat) -> CGFloat {
        (totalWidth * 0.57).rounded()
    }

    var body: some View {
        let theme = themeManager.current

        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── Top row ──────────────────────────────────────────────────
                HStack(spacing: 0) {
                    SystemPanel(monitor: sysMonitor)
                        .frame(width: geo.size.width * 0.16)
                        .augmentedPanel(theme, clipSize: 10,
                                        corners: [.bottomRight], lineWidth: 1)

                    TerminalPanel(fileWatcher: fileWatcher)
                        .frame(width: geo.size.width * 0.68)

                    NetworkPanel(networkMonitor: netMonitor, systemMonitor: sysMonitor)
                        .frame(width: geo.size.width * 0.16)
                        .augmentedPanel(theme, clipSize: 10,
                                        corners: [.bottomLeft], lineWidth: 1)
                }
                .frame(height: geo.size.height * 0.70)

                Divider().overlay(theme.borderColor.opacity(0.3))

                // ── Bottom row — filesystem + optional side-by-side keyboard ─
                HStack(spacing: 0) {
                    FileSystemPanel(fileWatcher: fileWatcher)
                        .frame(maxWidth: .infinity)
                        .augmentedPanel(theme, clipSize: 10,
                                        corners: [.topLeft, .topRight], lineWidth: 1)

                    if showKeyboard {
                        Divider().overlay(theme.borderColor.opacity(0.3))

                        KeyboardView()
                            .frame(width: keyboardWidth(for: geo.size.width))
                            .environment(\.edexTheme, themeManager.current)
                    }
                }
                .frame(height: geo.size.height * 0.30)
            }
        }
        .background(themeManager.current.bgMain)
        .environment(\.edexTheme, themeManager.current)
        .ignoresSafeArea()
        .onAppear {
            sysMonitor.start()
            netMonitor.start()
            fileWatcher.loadDirectory(path: NSHomeDirectory())
        }
    }
}
