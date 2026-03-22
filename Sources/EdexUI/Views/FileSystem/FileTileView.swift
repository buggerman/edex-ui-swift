import SwiftUI

// Mirrors src/components/filesystem/tile.tsx + icon.tsx
// Square tiles in an auto-fill grid — clicking directories sends `cd` to the active terminal

struct FileTileView: View {
    @Environment(\.edexTheme) var theme
    let entry: FileEntry
    let onTap: (FileEntry) -> Void

    var body: some View {
        Button(action: { onTap(entry) }) {
            VStack(spacing: 2) {
                fileIcon
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if entry.kind != .settings && entry.kind != .backward {
                    Text(entry.name)
                        .font(.edexMono(size: 10))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(3)
            .foregroundStyle(theme.textColor.opacity(entry.isHidden ? 0.4 : 1.0))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(theme.bgSecondary.opacity(0.25))
    }

    @ViewBuilder
    private var fileIcon: some View {
        switch entry.kind {
        case .directory:
            Image(systemName: "folder")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 18))
        case .file:
            Image(systemName: "doc")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 18))
        case .symlink:
            Image(systemName: "link")
                .font(.system(size: 18))
        case .backward:
            Image(systemName: "arrow.uturn.up")
                .font(.system(size: 18))
        case .settings:
            Image(systemName: "gearshape")
                .font(.system(size: 18))
        }
    }
}
