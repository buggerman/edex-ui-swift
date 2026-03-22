import SwiftUI
import Darwin

// Matches the compact 4-column layout in the Rust project screenshots:
//   2026   UPTIME   KERNEL   V
//   JAN 19 1:02:10  23.5.0  14.5.0

struct SysInfoView: View {
    @Environment(\.edexTheme) var theme
    let uptime: TimeInterval

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            col(header: yearString,   value: dateString)
            col(header: "UPTIME",     value: uptime.uptimeString)
            col(header: "KERNEL",     value: kernelVersion)
            col(header: "V",          value: osVersionShort)
        }
        .foregroundStyle(theme.textColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func col(header: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(header)
                .font(.edexMono(size: 9))
                .opacity(0.45)
            Text(value)
                .font(.edexMono(size: 9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Values

    private var yearString: String {
        "\(Calendar.current.component(.year, from: Date()))"
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date()).uppercased()
    }

    private var osVersionShort: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var kernelVersion: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.release) { bytes in
            String(bytes: bytes.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
        }
    }

    private var hwModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Unknown" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        return String(cString: buf)
    }
}
