import SwiftUI
import AppKit
import Carbon

// MARK: - Layout detector

final class KeyboardLayoutDetector: ObservableObject {
    enum FormFactor { case ansi, iso, jis }

    @Published var formFactor: FormFactor = .ansi
    @Published var normal:  [UInt16: String] = [:]   // unshifted label per keycode
    @Published var shifted: [UInt16: String] = [:]   // shifted label per keycode

    init() {
        refresh()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(layoutChanged),
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    deinit { DistributedNotificationCenter.default().removeObserver(self) }

    @objc private func layoutChanged() { DispatchQueue.main.async { self.refresh() } }

    func refresh() {
        let t = LMGetKbdType()
        formFactor = t == 41 ? .iso : t == 42 ? .jis : .ansi
        let (n, s) = translateAll()
        normal  = n
        shifted = s
    }

    // MARK: UCKeyTranslate

    private func translateAll() -> ([UInt16: String], [UInt16: String]) {
        guard
            let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let ref = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData)
        else { return ([:], [:]) }

        let data = Unmanaged<CFData>.fromOpaque(ref).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return ([:], [:]) }
        let layout = bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }
        let kbdType = UInt32(LMGetKbdType())

        // Printable key codes (excludes modifier-only keys)
        let codes: [UInt16] = [
            18, 19, 20, 21, 23, 22, 26, 28, 25, 29, // 1-0
            27, 24, 50,                              // - = `
            12, 13, 14, 15, 17, 16, 32, 34, 31, 35, // Q-P
            33, 30, 42,                              // [ ] backslash
            0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39,  // A-L ; '
            6, 7, 8, 9, 11, 45, 46, 43, 47, 44,    // Z-M , . /
            10,                                      // ISO § key
        ]

        var n: [UInt16: String] = [:]
        var s: [UInt16: String] = [:]

        for code in codes {
            if let label = xlate(layout, code, modifier: 0,        kbdType: kbdType) { n[code] = label }
            if let label = xlate(layout, code, modifier: 2,        kbdType: kbdType) { s[code] = label }
        }
        return (n, s)
    }

    private func xlate(_ layout: UnsafePointer<UCKeyboardLayout>,
                       _ code: UInt16, modifier: UInt32, kbdType: UInt32) -> String? {
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var len = 0
        let err = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), modifier, kbdType,
                                 OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                 &dead, 4, &len, &chars)
        guard err == noErr, len > 0, chars[0] != 0 else { return nil }
        let s = String(chars.prefix(len).compactMap { Unicode.Scalar($0).map(Character.init) })
                    .uppercased().trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }
}

// MARK: - Key definition

struct KeyDef {
    let label: String       // modifier keys use fixed text; printable keys use detector
    let code: UInt16
    let widthMultiplier: Double
    var isSpecial: Bool = false   // modifier keys — never translated
}

// MARK: - KeyboardView

struct KeyboardView: View {
    @Environment(\.edexTheme) var theme
    @StateObject private var detector = KeyboardLayoutDetector()
    @State private var pressed: Set<UInt16> = []
    @State private var monitor: Any?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 3) {
                ForEach(rows.indices, id: \.self) { i in
                    rowView(rows[i], totalWidth: geo.size.width)
                }
            }
            .padding(4)
        }
        .background(theme.bgSecondary.opacity(0.3))
        .onAppear(perform: startMonitoring)
        .onDisappear(perform: stopMonitoring)
    }

    // MARK: - Row data (ANSI/ISO selected via detector)

    private var rows: [[KeyDef]] {
        detector.formFactor == .iso ? isoRows : ansiRows
    }

    private var ansiRows: [[KeyDef]] {[
        [S("ESC",53,1.0), P("`",50,1.0), P("1",18,1.0), P("2",19,1.0), P("3",20,1.0),
         P("4",21,1.0), P("5",23,1.0), P("6",22,1.0), P("7",26,1.0), P("8",28,1.0),
         P("9",25,1.0), P("0",29,1.0), P("-",27,1.0), P("=",24,1.0), S("BACK",51,2.0)],

        [S("TAB",48,1.5), P("Q",12,1.0), P("W",13,1.0), P("E",14,1.0), P("R",15,1.0),
         P("T",17,1.0), P("Y",16,1.0), P("U",32,1.0), P("I",34,1.0), P("O",31,1.0),
         P("P",35,1.0), P("[",33,1.0), P("]",30,1.0), P("\\",42,1.0)],

        [S("CAPS",57,1.75), P("A",0,1.0), P("S",1,1.0), P("D",2,1.0), P("F",3,1.0),
         P("G",5,1.0), P("H",4,1.0), P("J",38,1.0), P("K",40,1.0), P("L",37,1.0),
         P(";",41,1.0), P("'",39,1.0), S("ENTER",36,2.25)],

        [S("SHIFT",56,2.25), P("Z",6,1.0), P("X",7,1.0), P("C",8,1.0), P("V",9,1.0),
         P("B",11,1.0), P("N",45,1.0), P("M",46,1.0), P(",",43,1.0), P(".",47,1.0),
         P("/",44,1.0), S("SHIFT",60,2.25)],

        [S("CTRL",59,1.5), S("FN",63,1.5), S("",49,5.5), S("ALT",58,1.5), S("CTRL",62,1.5),
         S("←",123,1.0), S("↓",125,1.0), S("→",124,1.0)],
    ]}

    private var isoRows: [[KeyDef]] {[
        [S("ESC",53,1.0), P("`",50,1.0), P("1",18,1.0), P("2",19,1.0), P("3",20,1.0),
         P("4",21,1.0), P("5",23,1.0), P("6",22,1.0), P("7",26,1.0), P("8",28,1.0),
         P("9",25,1.0), P("0",29,1.0), P("-",27,1.0), P("=",24,1.0), S("BACK",51,2.0)],

        [S("TAB",48,1.5), P("Q",12,1.0), P("W",13,1.0), P("E",14,1.0), P("R",15,1.0),
         P("T",17,1.0), P("Y",16,1.0), P("U",32,1.0), P("I",34,1.0), P("O",31,1.0),
         P("P",35,1.0), P("[",33,1.0), P("]",30,1.0), S("ENTER",36,1.75)],

        [S("CAPS",57,1.75), P("A",0,1.0), P("S",1,1.0), P("D",2,1.0), P("F",3,1.0),
         P("G",5,1.0), P("H",4,1.0), P("J",38,1.0), P("K",40,1.0), P("L",37,1.0),
         P(";",41,1.0), P("'",39,1.0), P("#",42,1.0)],

        [S("SHIFT",56,1.25), P("§",10,1.0), P("Z",6,1.0), P("X",7,1.0), P("C",8,1.0),
         P("V",9,1.0), P("B",11,1.0), P("N",45,1.0), P("M",46,1.0), P(",",43,1.0),
         P(".",47,1.0), P("/",44,1.0), S("SHIFT",60,2.25)],

        [S("CTRL",59,1.5), S("FN",63,1.5), S("",49,5.5), S("ALT",58,1.5), S("CTRL",62,1.5),
         S("←",123,1.0), S("↓",125,1.0), S("→",124,1.0)],
    ]}

    // Printable key — label and shifted label come from UCKeyTranslate
    private func P(_ fallback: String, _ code: UInt16, _ width: Double) -> KeyDef {
        KeyDef(label: fallback, code: code, widthMultiplier: width, isSpecial: false)
    }
    // Special/modifier key — label is always fixed text
    private func S(_ label: String, _ code: UInt16, _ width: Double) -> KeyDef {
        KeyDef(label: label, code: code, widthMultiplier: width, isSpecial: true)
    }

    // MARK: - Row renderer

    private func rowView(_ keys: [KeyDef], totalWidth: CGFloat) -> some View {
        let totalUnits = keys.reduce(0.0) { $0 + $1.widthMultiplier }
        let gaps   = Double(keys.count - 1) * 3.0
        let usable = Double(totalWidth - 8)
        let unit   = (usable - gaps) / totalUnits

        return HStack(spacing: 3) {
            ForEach(0..<keys.count, id: \.self) { i in
                let key = keys[i]
                let mainLabel   = key.isSpecial ? key.label : (detector.normal[key.code]  ?? key.label)
                let shiftLabel  = key.isSpecial ? ""        : (detector.shifted[key.code] ?? "")
                KeyCapView(
                    main:      mainLabel,
                    shift:     shiftLabel,
                    isPressed: pressed.contains(key.code),
                    theme:     theme
                )
                .frame(width: CGFloat(unit * key.widthMultiplier), height: 34)
            }
        }
    }

    // MARK: - Key events

    private func startMonitoring() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if event.type == .keyDown { self.pressed.insert(event.keyCode) }
            else                      { self.pressed.remove(event.keyCode) }
            return event
        }
    }
    private func stopMonitoring() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - Key cap

private struct KeyCapView: View {
    let main:      String   // primary character (large, bottom-centre)
    let shift:     String   // shifted character (small, top-left)
    let isPressed: Bool
    let theme:     EdexTheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isPressed ? theme.bgActive.opacity(0.35) : theme.bgSecondary.opacity(0.55))
            RoundedRectangle(cornerRadius: 3)
                .stroke(isPressed ? theme.borderColor.opacity(0.9) : theme.borderColor.opacity(0.3),
                        lineWidth: isPressed ? 1 : 0.5)

            // Shifted char — top-left, small
            if !shift.isEmpty && shift != main {
                Text(shift)
                    .font(.edexMono(size: 7))
                    .foregroundStyle(theme.textColor.opacity(0.5))
                    .padding(.leading, 3)
                    .padding(.top, 2)
            }

            // Main char — centred (slightly lower so shift label has room)
            Text(main)
                .font(.edexMono(size: 10))
                .foregroundStyle(theme.textColor.opacity(isPressed ? 1 : 0.85))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: shift.isEmpty || shift == main ? 0 : 3)
        }
    }
}
