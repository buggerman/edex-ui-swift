import SwiftUI
import AppKit

// Mirrors src/components/terminal/index.tsx + tab.tsx
// Multiple terminal sessions in a ZStack (all kept alive for correct resize/input handling)
// Keyboard shortcuts mirror the original: Ctrl+T new, Ctrl+W close, Ctrl+Tab switch

struct TerminalPanel: View {
    @Environment(\.edexTheme) var theme
    @ObservedObject var fileWatcher: FileWatcher

    @State private var tabs: [TerminalTab] = [TerminalTab(id: UUID(), title: "TERMINAL 1")]
    @State private var activeID: UUID = UUID()

    init(fileWatcher: FileWatcher) {
        self.fileWatcher = fileWatcher
        let id = UUID()
        _tabs     = State(initialValue: [TerminalTab(id: id, title: "TERMINAL 1")])
        _activeID = State(initialValue: id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TerminalTabBar(
                tabs: $tabs,
                activeID: $activeID,
                onAdd: addTab,
                onClose: closeTab
            )
            .background(theme.bgSecondary.opacity(0.6))

            Divider().overlay(theme.borderColor.opacity(0.3))

            // Terminal sessions — all rendered, only active one visible
            // ZStack keeps NSViews alive so xterm state and scroll position are preserved
            ZStack {
                ForEach(tabs) { tab in
                    TerminalSessionView(
                        theme: theme,
                        isActive: tab.id == activeID,
                        onCWDChange: { path in
                            if tab.id == activeID {
                                fileWatcher.updateCWD(path)
                            }
                        },
                        onProcessStart: { pid in
                            fileWatcher.setPID(pid)
                        }
                    )
                    .opacity(tab.id == activeID ? 1 : 0)
                    // Allow non-active terminals to receive no input without removing the view
                    .allowsHitTesting(tab.id == activeID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: theme.termBackground))
        }
        .background(theme.bgMain)
        // Keyboard shortcuts — mirrors original Ctrl+T/W/Tab bindings
        .onKeyboardShortcut("t", modifiers: .command) { addTab() }
        .onKeyboardShortcut("w", modifiers: .command) {
            if tabs.count > 1 { closeTab(activeID) }
        }
        // Ctrl+Tab / Ctrl+Shift+Tab cycle
        .background(
            KeyEventHandler(
                onCtrlTab:      { cycleTab(forward: true) },
                onCtrlShiftTab: { cycleTab(forward: false) }
            )
        )
    }

    // MARK: - Tab management

    private func addTab() {
        let n = tabs.count + 1
        let tab = TerminalTab(id: UUID(), title: "TERMINAL \(n)")
        tabs.append(tab)
        activeID = tab.id
    }

    private func closeTab(_ id: UUID) {
        guard tabs.count > 1, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        // Switch to neighbour before removing
        if activeID == id {
            let newIdx = idx > 0 ? idx - 1 : 1
            activeID = tabs[newIdx].id
        }
        tabs.remove(at: idx)
    }

    private func cycleTab(forward: Bool) {
        guard let idx = tabs.firstIndex(where: { $0.id == activeID }) else { return }
        let next = forward
            ? (idx + 1) % tabs.count
            : (idx - 1 + tabs.count) % tabs.count
        activeID = tabs[next].id
    }
}

// MARK: - Keyboard shortcut helpers

extension View {
    func onKeyboardShortcut(_ key: KeyEquivalent,
                            modifiers: EventModifiers = .command,
                            perform action: @escaping () -> Void) -> some View {
        self.keyboardShortcut(key, modifiers: modifiers)
            .simultaneousGesture(
                TapGesture().onEnded { _ in action() }
            )
    }
}

// MARK: - Ctrl+Tab NSEvent handler (not expressible via SwiftUI KeyboardShortcut)

private struct KeyEventHandler: NSViewRepresentable {
    let onCtrlTab: () -> Void
    let onCtrlShiftTab: () -> Void

    func makeNSView(context: Context) -> KeyHandlerView {
        let v = KeyHandlerView()
        v.onCtrlTab      = onCtrlTab
        v.onCtrlShiftTab = onCtrlShiftTab
        return v
    }
    func updateNSView(_ nsView: KeyHandlerView, context: Context) {
        nsView.onCtrlTab      = onCtrlTab
        nsView.onCtrlShiftTab = onCtrlShiftTab
    }
}

final class KeyHandlerView: NSView {
    var onCtrlTab:      (() -> Void)?
    var onCtrlShiftTab: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.control),
              event.keyCode == 48 /* Tab */ else {
            super.keyDown(with: event)
            return
        }
        if event.modifierFlags.contains(.shift) {
            onCtrlShiftTab?()
        } else {
            onCtrlTab?()
        }
    }
}

