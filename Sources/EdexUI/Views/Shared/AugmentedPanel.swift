import SwiftUI

// Recreates the augmented-ui CSS library's corner-clip border effect used throughout the original.
// data-augmented-ui="bl-clip tr-clip border" → bottom-left & top-right corners are clipped at 45°.

struct AugmentedShape: Shape {
    var clipSize: CGFloat
    var clippedCorners: Set<Corner>

    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    func path(in rect: CGRect) -> Path {
        let c = clipSize
        var p = Path()

        // Top-left
        if clippedCorners.contains(.topLeft) {
            p.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        // → top-right
        if clippedCorners.contains(.topRight) {
            p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX,     y: rect.minY + c))
        } else {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        // ↓ bottom-right
        if clippedCorners.contains(.bottomRight) {
            p.addLine(to: CGPoint(x: rect.maxX,     y: rect.maxY - c))
            p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        } else {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }

        // ← bottom-left
        if clippedCorners.contains(.bottomLeft) {
            p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX,     y: rect.maxY - c))
        } else {
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }

        // ↑ back to top-left
        if clippedCorners.contains(.topLeft) {
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        }
        p.closeSubpath()
        return p
    }
}

// Convenience modifier — matches ".panel" CSS class from index.css
struct AugmentedPanelModifier: ViewModifier {
    let theme: EdexTheme
    var clipSize: CGFloat = 8
    var corners: Set<AugmentedShape.Corner> = [.bottomLeft, .topRight]
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .clipShape(AugmentedShape(clipSize: clipSize, clippedCorners: corners))
            .overlay(
                AugmentedShape(clipSize: clipSize, clippedCorners: corners)
                    .stroke(theme.borderColor.opacity(0.4), lineWidth: lineWidth)
            )
    }
}

extension View {
    func augmentedPanel(_ theme: EdexTheme,
                        clipSize: CGFloat = 8,
                        corners: Set<AugmentedShape.Corner> = [.bottomLeft, .topRight],
                        lineWidth: CGFloat = 1) -> some View {
        modifier(AugmentedPanelModifier(theme: theme, clipSize: clipSize,
                                        corners: corners, lineWidth: lineWidth))
    }
}

// MARK: - Divider
// Mirrors <Divider /> component — thin horizontal line with theme border color
struct EdexDivider: View {
    @Environment(\.edexTheme) var theme
    var body: some View {
        Rectangle()
            .fill(theme.borderColor.opacity(0.25))
            .frame(height: 1)
            .padding(.horizontal, 4)
    }
}

// MARK: - Banner
// Mirrors <Banner title="PANEL" name="SYSTEM" /> — section header label
struct EdexBanner: View {
    let title: String
    let name: String
    var rightLabel: String = ""   // optional right-aligned label (e.g. location abbreviation)
    @Environment(\.edexTheme) var theme

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(title)
                .font(.edexMono(size: 9))
                .opacity(0.4)
            Text(name)
                .font(.edexMono(size: 11))
            Spacer(minLength: 0)
            if !rightLabel.isEmpty {
                Text(rightLabel)
                    .font(.edexMono(size: 8))
                    .opacity(0.45)
            }
        }
        .foregroundStyle(theme.textColor)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}
