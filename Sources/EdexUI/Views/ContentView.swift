import SwiftUI

// Root layout — mirrors App.tsx + proportions from index.css / App.tsx:
//   Top row:  System (16vw) | Terminal (68vw) | Network (16vw)  — 62vh tall
//   Bottom:   FileSystem (+ optional keyboard)                   — 38vh tall

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("showKeyboard") private var showKeyboard = false

    // Services are owned here and passed down to avoid duplicating @StateObject across panels
    @StateObject private var sysMonitor     = SystemMonitor()
    @StateObject private var netMonitor     = NetworkMonitor()
    @StateObject private var fileWatcher    = FileWatcher()

    private let keyboardHeight: CGFloat = 160

    var body: some View {
        let theme = themeManager.current

        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── Top row ──────────────────────────────────────────────────
                HStack(spacing: 0) {
                    // Left — System panel (16%)
                    SystemPanel(monitor: sysMonitor)
                        .frame(width: geo.size.width * 0.16)
                        .augmentedPanel(theme, clipSize: 10,
                                        corners: [.bottomRight], lineWidth: 1)

                    // Centre — Terminal (68%)
                    TerminalPanel(fileWatcher: fileWatcher)
                        .frame(width: geo.size.width * 0.68)

                    // Right — Network panel (16%)
                    NetworkPanel(networkMonitor: netMonitor, systemMonitor: sysMonitor)
                        .frame(width: geo.size.width * 0.16)
                        .augmentedPanel(theme, clipSize: 10,
                                        corners: [.bottomLeft], lineWidth: 1)
                }
                .frame(height: geo.size.height * 0.62)

                Divider()
                    .overlay(theme.borderColor.opacity(0.3))

                // ── Bottom — FileSystem (38%) + optional keyboard ────────────
                let bottomHeight = geo.size.height * 0.38
                let fsHeight = showKeyboard
                    ? max(0, bottomHeight - keyboardHeight)
                    : bottomHeight

                VStack(spacing: 0) {
                    FileSystemPanel(fileWatcher: fileWatcher)
                        .frame(height: fsHeight)
                        .augmentedPanel(theme, clipSize: 10,
                                        corners: [.topLeft, .topRight], lineWidth: 1)

                    if showKeyboard {
                        KeyboardView()
                            .frame(height: keyboardHeight)
                            .environment(\.edexTheme, themeManager.current)
                    }
                }
                .frame(height: bottomHeight)
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
