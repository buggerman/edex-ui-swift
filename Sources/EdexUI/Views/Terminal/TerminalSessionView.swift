import SwiftUI
import SwiftTerm
import AppKit

// Wraps SwiftTerm's LocalProcessTerminalView in NSViewRepresentable.
// Mirrors src/components/terminal/session.tsx + src-tauri/src/session/main.rs

struct TerminalSessionView: NSViewRepresentable {
    let theme: EdexTheme
    let isActive: Bool
    let onCWDChange: (String) -> Void
    let onProcessStart: (pid_t) -> Void

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        // Build environment — mirrors PTY setup in src-tauri/src/session/main.rs
        var env = Foundation.ProcessInfo.processInfo.environment
        env["TERM"]                 = "xterm-256color"
        env["COLORTERM"]            = "truecolor"
        env["TERM_PROGRAM"]         = "edex-ui"
        env["TERM_PROGRAM_VERSION"] = "1.0.0"

        let termView = LocalProcessTerminalView(frame: .zero)
        termView.processDelegate = context.coordinator

        // Set initial colors before starting the process
        applyColors(theme, to: termView)

        termView.startProcess(
            executable: "/bin/zsh",
            args: [],
            environment: env.map { "\($0.key)=\($0.value)" },
            execName: "zsh"
        )

        return termView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        applyColors(theme, to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCWDChange: onCWDChange, onProcessStart: onProcessStart)
    }

    // MARK: - Theme application
    // caretView.style is internal in SwiftTerm, so cursor style is baked into TerminalOptions
    // at makeNSView time; bg/fg/palette can be updated live via applyColors.

    private func applyColors(_ theme: EdexTheme, to view: LocalProcessTerminalView) {
        // Font — falls back to SF Mono if Fira Mono not installed
        let font = NSFont(name: theme.termFontFamily, size: 13)
                ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.font = font

        // Background + foreground colors — public properties on TerminalView
        if let bg = NSColor(hexString: theme.termBackground) {
            view.nativeBackgroundColor = bg
        }
        if let fg = NSColor(hexString: theme.termForeground) {
            view.nativeForegroundColor = fg
        }

        // 16-color ANSI palette
        view.installColors(makeColorTable(theme: theme))
    }

    private func cursorStyle(for theme: EdexTheme) -> CursorStyle {
        switch theme.termCursorStyle {
        case .block:     return .steadyBlock
        case .underline: return .steadyUnderline
        case .bar:       return .steadyBar
        }
    }

    // Build 16-entry SwiftTerm Color table from theme — mirrors terminal.ts theme generation
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
        // Themes without a full palette: derive 16 colors from the main foreground
        let dim = stColor(theme.termForeground, alpha: 0.5)
        let bright = stColor(theme.termForeground)
        return Array(repeating: dim, count: 8) + Array(repeating: bright, count: 8)
    }

    private func stColor(_ hex: String, alpha: Double = 1.0) -> SwiftTerm.Color {
        guard let ns = NSColor(hexString: hex) else {
            return SwiftTerm.Color(red: 200, green: 200, blue: 200)
        }
        let r = UInt16((ns.redComponent   * 65535).rounded())
        let g = UInt16((ns.greenComponent * 65535).rounded())
        let b = UInt16((ns.blueComponent  * 65535).rounded())
        return SwiftTerm.Color(red: r, green: g, blue: b)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let onCWDChange: (String) -> Void
        let onProcessStart: (pid_t) -> Void

        init(onCWDChange: @escaping (String) -> Void, onProcessStart: @escaping (pid_t) -> Void) {
            self.onCWDChange    = onCWDChange
            self.onProcessStart = onProcessStart
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory { onCWDChange(dir) }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // Terminal exited — parent panel handles cleanup via tab close
        }
    }
}

// MARK: - NSColor hex initialiser (separate name to avoid conflict with Extensions.swift Color.init(hex:))

extension NSColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else { return nil }
        self.init(
            calibratedRed: CGFloat((int >> 16) & 0xFF) / 255,
            green:         CGFloat((int >>  8) & 0xFF) / 255,
            blue:          CGFloat( int        & 0xFF) / 255,
            alpha: 1
        )
    }
}
