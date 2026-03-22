import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowConfigured = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Must be set before the first window is created.
        // SPM executables default to .prohibited; without this the app has no
        // Dock icon, no menu bar, and windows never come to front.
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        // SwiftUI creates its window lazily — it may not exist yet here,
        // so we also try in applicationDidBecomeActive.
        configureWindow()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        configureWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Private

    private func configureWindow() {
        guard !windowConfigured,
              let window = NSApp.windows.first(where: { $0.isKind(of: NSWindow.self) })
        else { return }
        windowConfigured = true

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)

        // Enter fullscreen — only if not already in it (safe to call multiple times)
        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }
}
