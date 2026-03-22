import SwiftUI

// MARK: - Theme Definition
// Directly ported from src/lib/themes/styles.ts

struct EdexTheme: Equatable {
    let name: String

    // Panel / UI colors
    let bgMain: Color
    let bgSecondary: Color
    let bgActive: Color
    let borderColor: Color
    let textColor: Color

    // Terminal colors
    let termForeground: String
    let termBackground: String
    let termCursor: String
    let termCursorAccent: String
    let termFontFamily: String
    let termCursorStyle: TermCursorStyle

    // Optional extended ANSI palette (used by CYBORG)
    let ansiColors: AnsiColors?

    enum TermCursorStyle { case block, underline, bar }

    struct AnsiColors: Equatable {
        var black, red, green, yellow, blue, magenta, cyan, white: String
        var brightBlack, brightRed, brightGreen, brightYellow: String
        var brightBlue, brightMagenta, brightCyan, brightWhite: String
    }
}

// MARK: - Theme Definitions
// Colors translated 1:1 from the TypeScript theme file

extension EdexTheme {
    static let tron = EdexTheme(
        name: "TRON",
        bgMain:       Color(hex: "#05080d"),
        bgSecondary:  Color(hex: "#08111a"),
        bgActive:     Color(hex: "#aacfd1"),
        borderColor:  Color(hex: "#aacfd1"),
        textColor:    Color(hex: "#aacfd1"),
        termForeground:   "#aacfd1",
        termBackground:   "#05080d",
        termCursor:       "#aacfd1",
        termCursorAccent: "#aacfd1",
        termFontFamily:   "Fira Mono",
        termCursorStyle:  .block,
        ansiColors: nil
    )

    static let apollo = EdexTheme(
        name: "APOLLO",
        bgMain:       Color(hex: "#191919"),
        bgSecondary:  Color(hex: "#222222"),
        bgActive:     Color(hex: "#ebebeb"),
        borderColor:  Color(hex: "#ebebeb"),
        textColor:    Color(hex: "#ebebeb"),
        termForeground:   "#ebebeb",
        termBackground:   "#191919",
        termCursor:       "#ebebeb",
        termCursorAccent: "#ebebeb",
        termFontFamily:   "Fira Mono",
        termCursorStyle:  .block,
        ansiColors: nil
    )

    static let blade = EdexTheme(
        name: "BLADE",
        bgMain:       Color(hex: "#090B0A"),
        bgSecondary:  Color(hex: "#111413"),
        bgActive:     Color(hex: "#cc5e37"),
        borderColor:  Color(hex: "#cc5e37"),
        textColor:    Color(hex: "#cc5e37"),
        termForeground:   "#cc5e37",
        termBackground:   "#090B0A",
        termCursor:       "#cc5e37",
        termCursorAccent: "#cc5e37",
        termFontFamily:   "Fira Mono",
        termCursorStyle:  .underline,
        ansiColors: nil
    )

    static let cyborg = EdexTheme(
        name: "CYBORG",
        bgMain:       Color(hex: "#0a3333"),
        bgSecondary:  Color(hex: "#0d3d3d"),
        bgActive:     Color(hex: "#5fd7d7"),
        borderColor:  Color(hex: "#5fd7d7"),
        textColor:    Color(hex: "#a3c2c2"),
        termForeground:   "#a3c2c2",
        termBackground:   "#0a3333",
        termCursor:       "#5cffff",
        termCursorAccent: "#85ff5c",
        termFontFamily:   "Fira Code",
        termCursorStyle:  .block,
        ansiColors: EdexTheme.AnsiColors(
            black: "#011f1f", red: "#ad3e5a", green: "#3cd66f", yellow: "#c5d63c",
            blue: "#3c4dd6", magenta: "#ad31ad", cyan: "#31adad", white: "#a3c2c2",
            brightBlack: "#454585", brightRed: "#eb0954", brightGreen: "#85ff5c",
            brightYellow: "#ffff5c", brightBlue: "#5c5cff", brightMagenta: "#ff47d6",
            brightCyan: "#5cffff", brightWhite: "#e6fafa"
        )
    )

    static let interstellar = EdexTheme(
        name: "INTERSTELLAR",
        bgMain:       Color(hex: "#dedede"),
        bgSecondary:  Color(hex: "#d0d0d0"),
        bgActive:     Color(hex: "#03A9F4"),
        borderColor:  Color(hex: "#03A9F4"),
        textColor:    Color(hex: "#03A9F4"),
        termForeground:   "#03A9F4",
        termBackground:   "#dedede",
        termCursor:       "#03A9F4",
        termCursorAccent: "#03A9F4",
        termFontFamily:   "Fira Mono",
        termCursorStyle:  .bar,
        ansiColors: nil
    )

    static let all: [EdexTheme] = [.tron, .apollo, .blade, .cyborg, .interstellar]
}

// MARK: - Environment Key

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: EdexTheme = .tron
}

extension EnvironmentValues {
    var edexTheme: EdexTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
