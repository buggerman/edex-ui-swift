import SwiftUI

// Mirrors src/components/system/sysinfo/
// Shows Date, Uptime, Kernel version, OS version

struct SysInfoView: View {
    @Environment(\.edexTheme) var theme
    let uptime: TimeInterval

    private var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var kernelVersion: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.release) { bytes in
            String(bytes: bytes.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE dd MMM yyyy"
        return f.string(from: Date()).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row(label: "DATE",   value: dateString)
            row(label: "UP",     value: uptime.uptimeString)
            row(label: "KERNEL", value: kernelVersion)
            row(label: "OS",     value: osVersion)
        }
        .foregroundStyle(theme.textColor)
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func row(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.edexMono(size: 9))
                .opacity(0.45)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.edexMono(size: 9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}
