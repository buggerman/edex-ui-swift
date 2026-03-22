import SwiftUI

struct TerminalTab: Identifiable {
    let id: UUID
    var title: String
    var isRenaming: Bool = false
}

struct TerminalTabBar: View {
    @Environment(\.edexTheme) var theme
    @Binding var tabs: [TerminalTab]
    @Binding var activeID: UUID
    let onAdd:   () -> Void
    let onClose: (UUID) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach($tabs) { $tab in
                TabCell(
                    tab: $tab,
                    isActive: tab.id == activeID,
                    theme: theme,
                    onSelect: { activeID = tab.id },
                    onClose:  { onClose(tab.id) }
                )
            }

            Button(action: onAdd) {
                Text("+")
                    .font(.edexMono(size: 14))
                    .foregroundStyle(theme.textColor.opacity(0.5))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .help("New Terminal (⌘T)")

            Spacer(minLength: 0)
        }
        .frame(height: 26)
        .padding(.horizontal, 4)
    }
}

// MARK: - Tab cell
// Selection and close are separate Buttons layered via overlay — this avoids the
// `.onTapGesture` + Button conflict where both fire on a single click.

private struct TabCell: View {
    @Binding var tab: TerminalTab
    let isActive: Bool
    let theme: EdexTheme
    let onSelect: () -> Void
    let onClose:  () -> Void

    @State private var editTitle: String = ""
    @FocusState private var renaming: Bool

    var body: some View {
        // Outer Button handles tab selection — wraps the background + label
        Button(action: onSelect) {
            ZStack {
                SkewedTabShape()
                    .fill(isActive
                          ? theme.bgActive.opacity(0.15)
                          : theme.bgSecondary.opacity(0.4))
                SkewedTabShape()
                    .stroke(theme.borderColor.opacity(isActive ? 0.6 : 0.2), lineWidth: 0.5)

                if tab.isRenaming {
                    TextField("", text: $editTitle)
                        .font(.edexMono(size: isActive ? 10 : 9))
                        .foregroundStyle(theme.textColor)
                        .textFieldStyle(.plain)
                        .focused($renaming)
                        .onAppear { editTitle = tab.title; renaming = true }
                        .onSubmit { commitRename() }
                        .padding(.horizontal, 8)
                } else {
                    Text(tab.title)
                        .font(.edexMono(size: isActive ? 10 : 9))
                        .foregroundStyle(theme.textColor.opacity(isActive ? 1 : 0.55))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: isActive ? 110 : 90, height: 22)
        .scaleEffect(isActive ? 1.0 : 0.93)
        .animation(.easeInOut(duration: 0.12), value: isActive)
        // Double-click to rename — ⌘W closes via keyboard shortcut
        .simultaneousGesture(TapGesture(count: 2).onEnded { tab.isRenaming = true })
    }

    private func commitRename() {
        tab.title      = editTitle.isEmpty ? tab.title : editTitle
        tab.isRenaming = false
    }
}

// MARK: - Skewed tab shape  (.skew-tab clip-path from the original CSS)

private struct SkewedTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX,        y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX,        y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX * 0.85, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX,        y: rect.minY))
        p.closeSubpath()
        return p
    }
}
