import SwiftUI
import AppKit

// eDEX-UI sci-fi QWERTY keyboard with live key-press highlighting

struct KeyDef {
    let label: String
    let code: UInt16
    let widthMultiplier: Double
}

struct KeyboardView: View {
    @Environment(\.edexTheme) var theme
    @State private var pressedKeyCodes: Set<UInt16> = []
    @State private var monitor: Any?

    // Key rows — keyCodes from macOS HID usage tables
    private let rows: [[KeyDef]] = [
        // Row 0: function/number row
        [
            KeyDef(label:"ESC",  code:53,  widthMultiplier:1.0),
            KeyDef(label:"`",    code:50,  widthMultiplier:1.0),
            KeyDef(label:"1",    code:18,  widthMultiplier:1.0),
            KeyDef(label:"2",    code:19,  widthMultiplier:1.0),
            KeyDef(label:"3",    code:20,  widthMultiplier:1.0),
            KeyDef(label:"4",    code:21,  widthMultiplier:1.0),
            KeyDef(label:"5",    code:23,  widthMultiplier:1.0),
            KeyDef(label:"6",    code:22,  widthMultiplier:1.0),
            KeyDef(label:"7",    code:26,  widthMultiplier:1.0),
            KeyDef(label:"8",    code:28,  widthMultiplier:1.0),
            KeyDef(label:"9",    code:25,  widthMultiplier:1.0),
            KeyDef(label:"0",    code:29,  widthMultiplier:1.0),
            KeyDef(label:"-",    code:27,  widthMultiplier:1.0),
            KeyDef(label:"=",    code:24,  widthMultiplier:1.0),
            KeyDef(label:"BACK", code:51,  widthMultiplier:2.0),
        ],
        // Row 1: QWERTY
        [
            KeyDef(label:"TAB",  code:48,  widthMultiplier:1.5),
            KeyDef(label:"Q",    code:12,  widthMultiplier:1.0),
            KeyDef(label:"W",    code:13,  widthMultiplier:1.0),
            KeyDef(label:"E",    code:14,  widthMultiplier:1.0),
            KeyDef(label:"R",    code:15,  widthMultiplier:1.0),
            KeyDef(label:"T",    code:17,  widthMultiplier:1.0),
            KeyDef(label:"Y",    code:16,  widthMultiplier:1.0),
            KeyDef(label:"U",    code:32,  widthMultiplier:1.0),
            KeyDef(label:"I",    code:34,  widthMultiplier:1.0),
            KeyDef(label:"O",    code:31,  widthMultiplier:1.0),
            KeyDef(label:"P",    code:35,  widthMultiplier:1.0),
            KeyDef(label:"[",    code:33,  widthMultiplier:1.0),
            KeyDef(label:"]",    code:30,  widthMultiplier:1.0),
            KeyDef(label:"\\",   code:42,  widthMultiplier:1.0),
        ],
        // Row 2: ASDF
        [
            KeyDef(label:"CAPS",  code:57,  widthMultiplier:1.75),
            KeyDef(label:"A",     code:0,   widthMultiplier:1.0),
            KeyDef(label:"S",     code:1,   widthMultiplier:1.0),
            KeyDef(label:"D",     code:2,   widthMultiplier:1.0),
            KeyDef(label:"F",     code:3,   widthMultiplier:1.0),
            KeyDef(label:"G",     code:5,   widthMultiplier:1.0),
            KeyDef(label:"H",     code:4,   widthMultiplier:1.0),
            KeyDef(label:"J",     code:38,  widthMultiplier:1.0),
            KeyDef(label:"K",     code:40,  widthMultiplier:1.0),
            KeyDef(label:"L",     code:37,  widthMultiplier:1.0),
            KeyDef(label:";",     code:41,  widthMultiplier:1.0),
            KeyDef(label:"'",     code:39,  widthMultiplier:1.0),
            KeyDef(label:"ENTER", code:36,  widthMultiplier:2.0),
        ],
        // Row 3: ZXCV
        [
            KeyDef(label:"SHIFT", code:56,  widthMultiplier:2.25),
            KeyDef(label:"Z",     code:6,   widthMultiplier:1.0),
            KeyDef(label:"X",     code:7,   widthMultiplier:1.0),
            KeyDef(label:"C",     code:8,   widthMultiplier:1.0),
            KeyDef(label:"V",     code:9,   widthMultiplier:1.0),
            KeyDef(label:"B",     code:11,  widthMultiplier:1.0),
            KeyDef(label:"N",     code:45,  widthMultiplier:1.0),
            KeyDef(label:"M",     code:46,  widthMultiplier:1.0),
            KeyDef(label:",",     code:43,  widthMultiplier:1.0),
            KeyDef(label:".",     code:47,  widthMultiplier:1.0),
            KeyDef(label:"/",     code:44,  widthMultiplier:1.0),
            KeyDef(label:"SHIFT", code:60,  widthMultiplier:2.25),
        ],
        // Row 4: bottom row
        [
            KeyDef(label:"CTRL",  code:59,  widthMultiplier:1.5),
            KeyDef(label:"FN",    code:63,  widthMultiplier:1.5),
            KeyDef(label:"SPACE", code:49,  widthMultiplier:5.0),
            KeyDef(label:"ALT",   code:58,  widthMultiplier:1.5),
            KeyDef(label:"CTRL",  code:62,  widthMultiplier:1.5),
        ],
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 3) {
                ForEach(rows.indices, id: \.self) { rowIdx in
                    keyRow(rows[rowIdx], totalWidth: geo.size.width)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .background(theme.bgSecondary.opacity(0.4))
        .onAppear(perform: startMonitoring)
        .onDisappear(perform: stopMonitoring)
    }

    // MARK: - Row builder

    private func keyRow(_ keys: [KeyDef], totalWidth: CGFloat) -> some View {
        let totalUnits = keys.reduce(0.0) { $0 + $1.widthMultiplier }
        let gapCount = Double(keys.count - 1)
        let gapTotal = gapCount * 3.0
        let usable = totalWidth - 8.0  // account for horizontal padding
        let unitWidth = (usable - gapTotal) / totalUnits

        return HStack(spacing: 3) {
            ForEach(keys.indices, id: \.self) { idx in
                let key = keys[idx]
                let keyWidth = unitWidth * key.widthMultiplier
                KeyCapView(
                    keyDef: key,
                    isPressed: pressedKeyCodes.contains(key.code),
                    theme: theme
                )
                .frame(width: keyWidth, height: 26)
            }
        }
    }

    // MARK: - Event monitoring

    private func startMonitoring() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            let code = event.keyCode
            if event.type == .keyDown {
                pressedKeyCodes.insert(code)
            } else {
                pressedKeyCodes.remove(code)
            }
            return event
        }
    }

    private func stopMonitoring() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

// MARK: - Individual key cap

private struct KeyCapView: View {
    let keyDef: KeyDef
    let isPressed: Bool
    let theme: EdexTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isPressed
                      ? theme.bgActive.opacity(0.3)
                      : theme.bgSecondary.opacity(0.5))
            RoundedRectangle(cornerRadius: 3)
                .stroke(isPressed
                        ? theme.borderColor.opacity(0.8)
                        : theme.borderColor.opacity(0.3),
                        lineWidth: isPressed ? 1.0 : 0.5)
            Text(keyDef.label)
                .font(.edexMono(size: 9))
                .foregroundStyle(theme.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}
