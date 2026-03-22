import SwiftUI
import SwiftTerm
import AppKit

// Wraps SwiftTerm's LocalProcessTerminalView in NSViewRepresentable.
// Exposes onRegisterSend so TerminalPanel can route cd commands from the filesystem panel.

struct TerminalSessionView: NSViewRepresentable {
    let theme: EdexTheme
    let isActive: Bool
    let onCWDChange:    (String) -> Void
    let onProcessStart: (pid_t) -> Void
    let onRegisterSend: (@escaping (String) -> Void) -> Void

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        var env = Foundation.ProcessInfo.processInfo.environment
        env["TERM"]                 = "xterm-256color"
        env["COLORTERM"]            = "truecolor"
        env["TERM_PROGRAM"]         = "edex-ui"
        env["TERM_PROGRAM_VERSION"] = "1.0.0"

        let termView = LocalProcessTerminalView(frame: .zero)
        termView.processDelegate = context.coordinator

        applyColors(theme, to: termView)

        termView.startProcess(
            executable: "/bin/zsh",
            args: [],
            environment: env.map { "\($0.key)=\($0.value)" },
            execName: "zsh"
        )

        // Ensure the terminal NSView gets first responder so keystrokes (incl. Tab) reach it
        DispatchQueue.main.async { termView.window?.makeFirstResponder(termView) }

        // Register the send closure so FileSystemPanel can write to this PTY
        onRegisterSend { text in
            let bytes = Array(text.utf8)
            termView.process.send(data: ArraySlice(bytes))
        }

        // Expose the shell PID for lsof CWD polling — wait briefly for posix_spawn to finish
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            let pid = termView.process.shellPid
            if pid > 0 { DispatchQueue.main.async { self.onProcessStart(pid) } }
        }

        return termView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        applyColors(theme, to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCWDChange: onCWDChange)
    }

    // MARK: - Theme

    private func applyColors(_ theme: EdexTheme, to view: LocalProcessTerminalView) {
        let font = NSFont(name: theme.termFontFamily, size: 13)
                ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.font = font
        if let bg = NSColor(hexString: theme.termBackground) { view.nativeBackgroundColor = bg }
        if let fg = NSColor(hexString: theme.termForeground) { view.nativeForegroundColor = fg }
        view.installColors(makeColorTable(theme: theme))
    }

    private func makeColorTable(theme: EdexTheme) -> [SwiftTerm.Color] {
        if let ansi = theme.ansiColors {
            return [
                stColor(ansi.black),       stColor(ansi.red),
                stColor(ansi.green),       stColor(ansi.yellow),
                stColor(ansi.blue),        stColor(ansi.magenta),
                stColor(ansi.cyan),        stColor(ansi.white),
                stColor(ansi.brightBlack), stColor(ansi.brightRed),
                stColor(ansi.brightGreen), stColor(ansi.brightYellow),
                stColor(ansi.brightBlue),  stColor(ansi.brightMagenta),
                stColor(ansi.brightCyan),  stColor(ansi.brightWhite),
            ]
        }
        let dim    = stColor(theme.termForeground, alpha: 0.5)
        let bright = stColor(theme.termForeground)
        return Array(repeating: dim, count: 8) + Array(repeating: bright, count: 8)
    }

    private func stColor(_ hex: String, alpha: Double = 1.0) -> SwiftTerm.Color {
        guard let ns = NSColor(hexString: hex) else { return SwiftTerm.Color(red: 200, green: 200, blue: 200) }
        return SwiftTerm.Color(red: UInt16((ns.redComponent   * 65535).rounded()),
                               green: UInt16((ns.greenComponent * 65535).rounded()),
                               blue:  UInt16((ns.blueComponent  * 65535).rounded()))
    }

    private func cursorStyle(for theme: EdexTheme) -> CursorStyle {
        switch theme.termCursorStyle {
        case .block:     return .steadyBlock
        case .underline: return .steadyUnderline
        case .bar:       return .steadyBar
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let onCWDChange: (String) -> Void
        init(onCWDChange: @escaping (String) -> Void) { self.onCWDChange = onCWDChange }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory { onCWDChange(dir) }
        }
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}

// MARK: - NSColor hex init

extension NSColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else { return nil }
        self.init(calibratedRed: CGFloat((int >> 16) & 0xFF) / 255,
                  green: CGFloat((int >>  8) & 0xFF) / 255,
                  blue:  CGFloat( int        & 0xFF) / 255,
                  alpha: 1)
    }
}
