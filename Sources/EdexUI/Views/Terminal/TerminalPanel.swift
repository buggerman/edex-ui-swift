import SwiftUI
import AppKit

// Mirrors src/components/terminal/index.tsx + tab.tsx

struct TerminalPanel: View {
    @Environment(\.edexTheme) var theme
    @ObservedObject var fileWatcher: FileWatcher

    @State private var tabs: [TerminalTab]
    @State private var activeID: UUID
    // send functions registered by each TerminalSessionView on creation
    @State private var sendHandlers: [UUID: (String) -> Void] = [:]

    init(fileWatcher: FileWatcher) {
        self.fileWatcher = fileWatcher
        let id = UUID()
        _tabs     = State(initialValue: [TerminalTab(id: id, title: "TERMINAL 1")])
        _activeID = State(initialValue: id)
    }

    var body: some View {
        VStack(spacing: 0) {
            TerminalTabBar(
                tabs: $tabs,
                activeID: $activeID,
                onAdd: addTab,
                onClose: closeTab
            )
            .background(theme.bgSecondary.opacity(0.6))

            Divider().overlay(theme.borderColor.opacity(0.3))

            ZStack {
                ForEach(tabs) { tab in
                    TerminalSessionView(
                        theme: theme,
                        isActive: tab.id == activeID,
                        onCWDChange: { path in
                            if tab.id == activeID { fileWatcher.updateCWD(path) }
                        },
                        onProcessStart: { pid in
                            if tab.id == activeID { fileWatcher.setPID(pid) }
                        },
                        onRegisterSend: { sendFn in
                            sendHandlers[tab.id] = sendFn
                            // If this is the first/active tab, wire it up immediately
                            if tab.id == activeID { fileWatcher.sendToTerminal = sendFn }
                        }
                    )
                    .opacity(tab.id == activeID ? 1 : 0)
                    .allowsHitTesting(tab.id == activeID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: theme.termBackground))
            // NSView-level key handler: intercepts Cmd+T/W/[/] and Ctrl+Tab before
            // the system responder chain can steal them (terminal NSView eats all keys)
            .background(
                KeyHandlerView(
                    onCmdT:         addTab,
                    onCmdW:         { if tabs.count > 1 { closeTab(activeID) } },
                    onCtrlTab:      { cycleTab(forward: true) },
                    onCtrlShiftTab: { cycleTab(forward: false) }
                )
            )
        }
        .background(theme.bgMain)
        .onChange(of: activeID) { _, id in
            fileWatcher.sendToTerminal = sendHandlers[id]
        }
    }

    // MARK: - Tab management

    private func addTab() {
        let n   = tabs.count + 1
        let tab = TerminalTab(id: UUID(), title: "TERMINAL \(n)")
        tabs.append(tab)
        activeID = tab.id
    }

    private func closeTab(_ id: UUID) {
        guard tabs.count > 1, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        if activeID == id {
            activeID = tabs[idx > 0 ? idx - 1 : 1].id
        }
        sendHandlers.removeValue(forKey: id)
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

// MARK: - NSView key handler
// Handles shortcuts that need to be intercepted before the terminal NSView
// consumes them. performKeyEquivalent fires on all views in the hierarchy,
// so this works even when LocalProcessTerminalView is first responder.

private struct KeyHandlerView: NSViewRepresentable {
    let onCmdT:         () -> Void
    let onCmdW:         () -> Void
    let onCtrlTab:      () -> Void
    let onCtrlShiftTab: () -> Void

    func makeNSView(context: Context) -> _KeyHandlerNSView {
        let v = _KeyHandlerNSView()
        v.update(self)
        return v
    }
    func updateNSView(_ nsView: _KeyHandlerNSView, context: Context) {
        nsView.update(self)
    }
}

final class _KeyHandlerNSView: NSView {
    private var onCmdT:         (() -> Void)?
    private var onCmdW:         (() -> Void)?
    private var onCtrlTab:      (() -> Void)?
    private var onCtrlShiftTab: (() -> Void)?

    // fileprivate: parameter type KeyHandlerView is private to this file
    fileprivate func update(_ rep: KeyHandlerView) {
        onCmdT         = rep.onCmdT
        onCmdW         = rep.onCmdW
        onCtrlTab      = rep.onCtrlTab
        onCtrlShiftTab = rep.onCtrlShiftTab
    }

    override var acceptsFirstResponder: Bool { false } // don't steal focus

    // performKeyEquivalent is called on every view in the window hierarchy
    // for Cmd+key shortcuts — this runs before the system acts on them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let cmd   = event.modifierFlags.contains(.command)
        let ctrl  = event.modifierFlags.contains(.control)
        let shift = event.modifierFlags.contains(.shift)
        let key   = event.charactersIgnoringModifiers ?? ""

        if cmd && key == "t" { DispatchQueue.main.async { self.onCmdT?() }; return true }
        if cmd && key == "w" { DispatchQueue.main.async { self.onCmdW?() }; return true }
        if ctrl && event.keyCode == 48 {   // Tab = keyCode 48
            if shift { DispatchQueue.main.async { self.onCtrlShiftTab?() } }
            else      { DispatchQueue.main.async { self.onCtrlTab?() } }
            return true
        }
        return false
    }
}
