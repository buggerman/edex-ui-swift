import SwiftUI

// MARK: - Color from hex string (used by Theme.swift)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Byte formatting  (replaces pretty-bytes npm package)
extension Int64 {
    var prettyBytes: String { formatBytes(Double(self)) }
}
extension UInt64 {
    var prettyBytes: String { formatBytes(Double(self)) }
}
extension Double {
    var prettyBytes: String { formatBytes(self) }
}

private func formatBytes(_ bytes: Double) -> String {
    guard bytes > 0 else { return "0 B" }
    let units = ["B", "KB", "MB", "GB", "TB"]
    let i = Int(log10(bytes) / 3)
    let clamped = min(i, units.count - 1)
    let value = bytes / pow(1000, Double(clamped))
    return value < 10
        ? String(format: "%.2f %@", value, units[clamped])
        : String(format: "%.1f %@", value, units[clamped])
}

// MARK: - Uptime formatting
extension TimeInterval {
    var uptimeString: String {
        let totalSeconds = Int(self)
        let days    = totalSeconds / 86400
        let hours   = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        if days > 0    { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0   { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - Font helper  (falls back to SF Mono if Fira Mono is not installed)
extension Font {
    static func edexMono(size: CGFloat) -> Font {
        if NSFont(name: "FiraMono-Regular", size: size) != nil {
            return .custom("FiraMono-Regular", size: size)
        }
        return .system(size: size, weight: .regular, design: .monospaced)
    }

    static func edexCode(size: CGFloat) -> Font {
        if NSFont(name: "FiraCode-Regular", size: size) != nil {
            return .custom("FiraCode-Regular", size: size)
        }
        return .system(size: size, weight: .regular, design: .monospaced)
    }
}

// MARK: - View modifier for uniform monospace label style
struct MonoLabelStyle: ViewModifier {
    let size: CGFloat
    let opacity: Double
    func body(content: Content) -> some View {
        content.font(.edexMono(size: size)).opacity(opacity)
    }
}
extension View {
    func monoLabel(size: CGFloat, opacity: Double = 1) -> some View {
        modifier(MonoLabelStyle(size: size, opacity: opacity))
    }
}
