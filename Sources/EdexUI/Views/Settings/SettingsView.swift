import SwiftUI

// Mirrors src/components/setting/index.tsx
// Theme picker + hidden files toggle + keyboard toggle + keyboard shortcuts reference

struct SettingsView: View {
    @Environment(\.edexTheme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("showKeyboard") private var showKeyboard = false
    @AppStorage("showWorldMap") private var showWorldMap = false

    let showHidden: Bool
    let onToggleHidden: (Bool) -> Void

    @State private var localShowHidden: Bool

    init(showHidden: Bool, onToggleHidden: @escaping (Bool) -> Void) {
        self.showHidden     = showHidden
        self.onToggleHidden = onToggleHidden
        _localShowHidden    = State(initialValue: showHidden)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("SETTINGS")
                    .font(.edexMono(size: 14))
                Spacer()
                Button("CLOSE") { dismiss() }
                    .font(.edexMono(size: 10))
                    .foregroundStyle(theme.textColor.opacity(0.6))
                    .buttonStyle(.plain)
            }
            .foregroundStyle(theme.textColor)
            .padding(14)
            .background(theme.bgSecondary)

            Divider().overlay(theme.borderColor.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Theme selection
                    settingsSection("THEME") {
                        HStack(spacing: 8) {
                            ForEach(EdexTheme.all, id: \.name) { t in
                                ThemeSwatchView(
                                    themeName: t.name,
                                    accentColor: t.bgActive,
                                    isSelected: themeManager.current.name == t.name
                                ) {
                                    themeManager.select(t)
                                }
                            }
                        }
                    }

                    // Filesystem options
                    settingsSection("FILESYSTEM") {
                        Toggle(isOn: $localShowHidden) {
                            Text("Show hidden files")
                                .font(.edexMono(size: 11))
                                .foregroundStyle(theme.textColor)
                        }
                        .toggleStyle(.switch)
                        .onChange(of: localShowHidden) { _, v in onToggleHidden(v) }
                    }

                    // Interface options
                    settingsSection("INTERFACE") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $showKeyboard) {
                                Text("Show virtual keyboard")
                                    .font(.edexMono(size: 11))
                                    .foregroundStyle(theme.textColor)
                            }
                            .toggleStyle(.switch)
                            Toggle(isOn: $showWorldMap) {
                                Text("Show world map in network panel")
                                    .font(.edexMono(size: 11))
                                    .foregroundStyle(theme.textColor)
                            }
                            .toggleStyle(.switch)
                        }
                    }

                    // Keyboard shortcuts reference
                    settingsSection("KEYBOARD SHORTCUTS") {
                        VStack(alignment: .leading, spacing: 4) {
                            shortcutRow("⌘T",          "New terminal tab")
                            shortcutRow("⌘W",          "Close terminal tab")
                            shortcutRow("⌃Tab",        "Next terminal tab")
                            shortcutRow("⌃⇧Tab",       "Previous terminal tab")
                            shortcutRow("Double-click tab", "Rename tab")
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.bgMain)
        }
        .background(theme.bgMain)
        .foregroundStyle(theme.textColor)
        .frame(width: 420, height: 380)
        .augmentedPanel(theme, clipSize: 12, corners: [.topLeft, .bottomRight], lineWidth: 1)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String,
                                               @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.edexMono(size: 9))
                .opacity(0.45)
            content()
        }
    }

    private func shortcutRow(_ keys: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.edexMono(size: 10))
                .frame(width: 110, alignment: .leading)
            Text(description)
                .font(.edexMono(size: 10))
                .opacity(0.7)
        }
    }
}

// MARK: - Theme colour swatch

private struct ThemeSwatchView: View {
    let themeName: String
    let accentColor: Color
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle().stroke(.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
                    )
                Text(themeName)
                    .font(.edexMono(size: 7))
                    .opacity(isSelected ? 1 : 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}
