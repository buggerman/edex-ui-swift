import AppKit

// Handles macOS app lifecycle:
//   • Launches in fullscreen (matches Tauri's `"fullscreen": true` in tauri.conf.json)
//   • Hides title bar for the sci-fi aesthetic
//   • Quits when the last window is closed

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let window = NSApp.windows.first else { return }

        // Hide traffic lights while keeping the native window chrome usable
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)

        // Enter fullscreen — mirrors tauri.conf.json "fullscreen": true
        DispatchQueue.main.async {
            window.toggleFullScreen(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
