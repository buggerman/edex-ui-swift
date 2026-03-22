import SwiftUI

// Mirrors src/components/terminal/tab.tsx
// Skewed tabs (clip-path: polygon), active tab scaled, inline rename

struct TerminalTab: Identifiable {
    let id: UUID
    var title: String
    var isRenaming: Bool = false
}

struct TerminalTabBar: View {
    @Environment(\.edexTheme) var theme
    @Binding var tabs: [TerminalTab]
    @Binding var activeID: UUID
    let onAdd: () -> Void
    let onClose: (UUID) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach($tabs) { $tab in
                TabCell(
                    tab: $tab,
                    isActive: tab.id == activeID,
                    theme: theme
                ) {
                    activeID = tab.id
                } onClose: {
                    onClose(tab.id)
                }
            }

            // "+" new terminal button
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

// MARK: - Individual tab cell

private struct TabCell: View {
    @Binding var tab: TerminalTab
    let isActive: Bool
    let theme: EdexTheme
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var editTitle: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Skewed background — mirrors `.skew-tab` clip-path
            SkewedTabShape()
                .fill(isActive
                    ? theme.bgActive.opacity(0.15)
                    : theme.bgSecondary.opacity(0.4))

            SkewedTabShape()
                .stroke(theme.borderColor.opacity(isActive ? 0.6 : 0.2), lineWidth: 0.5)

            HStack(spacing: 4) {
                if tab.isRenaming {
                    TextField("", text: $editTitle)
                        .font(.edexMono(size: isActive ? 10 : 9))
                        .foregroundStyle(theme.textColor)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onAppear { editTitle = tab.title; isFocused = true }
                        .onSubmit { commitRename() }
                } else {
                    Text(tab.title)
                        .font(.edexMono(size: isActive ? 10 : 9))
                        .foregroundStyle(theme.textColor.opacity(isActive ? 1 : 0.55))
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            tab.isRenaming = true
                        }
                }

                if isActive {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(theme.textColor.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(width: isActive ? 110 : 90, height: 22)
        .scaleEffect(isActive ? 1.0 : 0.93)
        .onTapGesture { onSelect() }
        .animation(.easeInOut(duration: 0.12), value: isActive)
    }

    private func commitRename() {
        tab.title = editTitle.isEmpty ? tab.title : editTitle
        tab.isRenaming = false
    }
}

// MARK: - Skewed tab shape
// Mirrors `.skew-tab { clip-path: polygon(0% 100%, 100% 100%, 85% 0%, 0% 0%) }`

private struct SkewedTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX,           y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX,         y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX * 0.85,  y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX,          y: rect.minY))
        p.closeSubpath()
        return p
    }
}
