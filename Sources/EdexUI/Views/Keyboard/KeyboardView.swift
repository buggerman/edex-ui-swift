import SwiftUI
import AppKit
import Carbon

// MARK: - Layout detector

/// Detects the physical keyboard form factor (ANSI / ISO / JIS) and translates
/// key codes to their current software-layout labels using UCKeyTranslate.
/// Re-runs whenever the user changes their input source.
final class KeyboardLayoutDetector: ObservableObject {
    enum FormFactor { case ansi, iso, jis }

    @Published var formFactor: FormFactor = .ansi
    @Published var keyLabels: [UInt16: String] = [:]

    private var observer: CFRunLoopSource?

    init() {
        refresh()
        // Re-translate when the user changes input source in System Settings
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(layoutChanged),
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func layoutChanged() {
        DispatchQueue.main.async { self.refresh() }
    }

    func refresh() {
        // Physical form factor via LMGetKbdType()
        // 40 = ANSI, 41 = ISO, 42 = JIS (standard Mac values)
        let kbdType = LMGetKbdType()
        switch kbdType {
        case 41:  formFactor = .iso
        case 42:  formFactor = .jis
        default:  formFactor = .ansi
        }

        keyLabels = translateAll()
    }

    // MARK: - UCKeyTranslate

    private func translateAll() -> [UInt16: String] {
        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let dataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return [:] }

        let cfData = Unmanaged<CFData>.fromOpaque(dataRef).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(cfData) else { return [:] }
        let layout = bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }

        // All printable key codes we care about labelling
        let codes: [UInt16] = [
            // Number row
            18, 19, 20, 21, 23, 22, 26, 28, 25, 29, // 1-0
            27, 24, 50,                              // - = `
            // QWERTY row
            12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42, // Q-P, [, ], \
            // ASDF row
            0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39,  // A-L, ;, '
            // ZXCV row
            6, 7, 8, 9, 11, 45, 46, 43, 47, 44,    // Z-M, ,, ., /
            10,                                      // ISO-only key (§ / < / `)
        ]

        var labels: [UInt16: String] = [:]
        let kbdType32 = UInt32(LMGetKbdType())

        for code in codes {
            var dead: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var len = 0
            let err = UCKeyTranslate(
                layout, code, UInt16(kUCKeyActionDown),
                0, kbdType32,
                OptionBits(kUCKeyTranslateNoDeadKeysMask),
                &dead, 4, &len, &chars
            )
            if err == noErr, len > 0, chars[0] != 0 {
                let s = String(chars.prefix(len).compactMap { Unicode.Scalar($0).map(Character.init) })
                    .uppercased()
                    .trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { labels[code] = s }
            }
        }
        return labels
    }
}

// MARK: - KeyDef

struct KeyDef {
    let label: String       // fallback label (modifier keys, fixed labels)
    let code: UInt16
    let widthMultiplier: Double
}

// MARK: - KeyboardView

struct KeyboardView: View {
    @Environment(\.edexTheme) var theme
    @StateObject private var detector = KeyboardLayoutDetector()
    @State private var pressedKeyCodes: Set<UInt16> = []
    @State private var monitor: Any?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 3) {
                ForEach(rows(for: detector.formFactor).indices, id: \.self) { i in
                    keyRow(rows(for: detector.formFactor)[i], totalWidth: geo.size.width)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .background(theme.bgSecondary.opacity(0.4))
        .onAppear(perform: startMonitoring)
        .onDisappear(perform: stopMonitoring)
    }

    // MARK: - Row layouts

    private func rows(for form: KeyboardLayoutDetector.FormFactor) -> [[KeyDef]] {
        switch form {
        case .iso: return isoRows
        case .jis: return ansiRows   // JIS rendered as ANSI for now
        case .ansi: return ansiRows
        }
    }

    // Helper: translates a keyCode to its current layout label, falling back to the KeyDef's label
    private func label(_ def: KeyDef) -> String {
        detector.keyLabels[def.code] ?? def.label
    }

    private var ansiRows: [[KeyDef]] {[
        // Row 0: number row
        [K("ESC",53,1.0), K("`",50,1.0), K("1",18,1.0), K("2",19,1.0), K("3",20,1.0),
         K("4",21,1.0), K("5",23,1.0), K("6",22,1.0), K("7",26,1.0), K("8",28,1.0),
         K("9",25,1.0), K("0",29,1.0), K("-",27,1.0), K("=",24,1.0), K("⌫",51,2.0)],
        // Row 1: QWERTY
        [K("⇥",48,1.5), K("Q",12,1.0), K("W",13,1.0), K("E",14,1.0), K("R",15,1.0),
         K("T",17,1.0), K("Y",16,1.0), K("U",32,1.0), K("I",34,1.0), K("O",31,1.0),
         K("P",35,1.0), K("[",33,1.0), K("]",30,1.0), K("\\",42,1.0)],
        // Row 2: ASDF
        [K("⇪",57,1.75), K("A",0,1.0), K("S",1,1.0), K("D",2,1.0), K("F",3,1.0),
         K("G",5,1.0), K("H",4,1.0), K("J",38,1.0), K("K",40,1.0), K("L",37,1.0),
         K(";",41,1.0), K("'",39,1.0), K("↩",36,2.25)],
        // Row 3: ZXCV
        [K("⇧",56,2.25), K("Z",6,1.0), K("X",7,1.0), K("C",8,1.0), K("V",9,1.0),
         K("B",11,1.0), K("N",45,1.0), K("M",46,1.0), K(",",43,1.0), K(".",47,1.0),
         K("/",44,1.0), K("⇧",60,2.25)],
        // Row 4: bottom
        [K("⌃",59,1.5), K("FN",63,1.5), K(" ",49,5.0), K("⌥",58,1.5), K("⌃",62,1.5)],
    ]}

    private var isoRows: [[KeyDef]] {[
        // Row 0: same as ANSI
        [K("ESC",53,1.0), K("`",50,1.0), K("1",18,1.0), K("2",19,1.0), K("3",20,1.0),
         K("4",21,1.0), K("5",23,1.0), K("6",22,1.0), K("7",26,1.0), K("8",28,1.0),
         K("9",25,1.0), K("0",29,1.0), K("-",27,1.0), K("=",24,1.0), K("⌫",51,2.0)],
        // Row 1: QWERTY — no backslash, Enter at end (top of L)
        [K("⇥",48,1.5), K("Q",12,1.0), K("W",13,1.0), K("E",14,1.0), K("R",15,1.0),
         K("T",17,1.0), K("Y",16,1.0), K("U",32,1.0), K("I",34,1.0), K("O",31,1.0),
         K("P",35,1.0), K("[",33,1.0), K("]",30,1.0), K("↩",36,1.75)],
        // Row 2: ASDF — extra ISO key (code 42, # on UK) before ENTER (bottom of L)
        [K("⇪",57,1.75), K("A",0,1.0), K("S",1,1.0), K("D",2,1.0), K("F",3,1.0),
         K("G",5,1.0), K("H",4,1.0), K("J",38,1.0), K("K",40,1.0), K("L",37,1.0),
         K(";",41,1.0), K("'",39,1.0), K("#",42,1.0)],
        // Row 3: ZXCV — narrow left shift, ISO key (code 10, § on UK) between shift and Z
        [K("⇧",56,1.25), K("§",10,1.0), K("Z",6,1.0), K("X",7,1.0), K("C",8,1.0),
         K("V",9,1.0), K("B",11,1.0), K("N",45,1.0), K("M",46,1.0), K(",",43,1.0),
         K(".",47,1.0), K("/",44,1.0), K("⇧",60,2.25)],
        // Row 4: same as ANSI
        [K("⌃",59,1.5), K("FN",63,1.5), K(" ",49,5.0), K("⌥",58,1.5), K("⌃",62,1.5)],
    ]}

    // Convenience constructor — reads translated label for printable keys
    private func K(_ fallback: String, _ code: UInt16, _ width: Double) -> KeyDef {
        KeyDef(label: fallback, code: code, widthMultiplier: width)
    }

    // MARK: - Row renderer

    private func keyRow(_ keys: [KeyDef], totalWidth: CGFloat) -> some View {
        let totalUnits = keys.reduce(0.0) { $0 + $1.widthMultiplier }
        let gaps       = Double(keys.count - 1) * 3.0
        let usable     = Double(totalWidth - 8)
        let unit       = (usable - gaps) / totalUnits

        return HStack(spacing: 3) {
            ForEach(0..<keys.count, id: \.self) { i in
                let key = keys[i]
                KeyCapView(
                    label:     label(key),
                    isPressed: pressedKeyCodes.contains(key.code),
                    theme:     theme
                )
                .frame(width: CGFloat(unit * key.widthMultiplier), height: 26)
            }
        }
    }

    // MARK: - Key event monitoring

    private func startMonitoring() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if event.type == .keyDown { self.pressedKeyCodes.insert(event.keyCode) }
            else                      { self.pressedKeyCodes.remove(event.keyCode) }
            return event
        }
    }

    private func stopMonitoring() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - Key cap

private struct KeyCapView: View {
    let label: String
    let isPressed: Bool
    let theme: EdexTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isPressed ? theme.bgActive.opacity(0.3) : theme.bgSecondary.opacity(0.5))
            RoundedRectangle(cornerRadius: 3)
                .stroke(isPressed ? theme.borderColor.opacity(0.8) : theme.borderColor.opacity(0.3),
                        lineWidth: isPressed ? 1 : 0.5)
            Text(label)
                .font(.edexMono(size: 9))
                .foregroundStyle(theme.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}
