import SwiftUI

// Mirrors src/components/system/clock/index.tsx
// Spaced digits, styled colons — same proportions as the original

struct ClockView: View {
    @Environment(\.edexTheme) var theme
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeString: String {
        let cal = Calendar.current
        let h = cal.component(.hour,   from: now)
        let m = cal.component(.minute, from: now)
        let s = cal.component(.second, from: now)
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var body: some View {
        GeometryReader { geo in
            let fontSize = geo.size.height * 0.42
            HStack(spacing: 0) {
                ForEach(Array(timeString.enumerated()), id: \.offset) { _, ch in
                    if ch == ":" {
                        Text(":")
                            .font(.system(size: fontSize, weight: .light, design: .default))
                            .frame(width: fontSize * 0.35)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(String(ch))
                            .font(.system(size: fontSize, weight: .light, design: .monospaced))
                            .frame(width: fontSize * 0.55)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .foregroundStyle(theme.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 56)
        .onReceive(timer) { now = $0 }
    }
}
