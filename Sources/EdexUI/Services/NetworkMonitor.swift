import Foundation
import Darwin
import Network

// Mirrors the Rust network traffic polling in src-tauri/src/sys/main.rs
// Uses getifaddrs for byte counters (same data source as the Rust `networks` sysinfo crate)

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var traffic = NetworkTraffic()
    @Published var state: NetworkState = .online
    @Published var latency: String = "--"

    private var timer: Timer?
    private var prevReceived: UInt64 = 0
    private var prevTransmitted: UInt64 = 0

    private let pathMonitor = NWPathMonitor()
    private let pathQueue   = DispatchQueue(label: "net.edex.path")

    func start() {
        // NWPathMonitor for online/offline — mirrors navigator.onLine in the JS version
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.state = path.status == .satisfied ? .online : .offline
            }
        }
        pathMonitor.start(queue: pathQueue)

        // Seed previous values
        let sample = readIfBytes()
        prevReceived    = sample.0
        prevTransmitted = sample.1

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
        schedulePingCheck()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pathMonitor.cancel()
    }

    // MARK: - Private

    private func poll() {
        let (recv, xmit) = readIfBytes()
        let receiveRate  = recv  >= prevReceived    ? Double(recv  - prevReceived)    : 0
        let transmitRate = xmit  >= prevTransmitted ? Double(xmit  - prevTransmitted) : 0
        prevReceived    = recv
        prevTransmitted = xmit
        traffic = NetworkTraffic(
            receiveRate:    receiveRate,
            transmitRate:   transmitRate,
            totalReceived:  recv,
            totalTransmitted: xmit
        )
    }

    // Reads total bytes across all non-loopback interfaces — same as getifaddrs approach in Rust
    private func readIfBytes() -> (UInt64, UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let head = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var recv: UInt64 = 0
        var xmit: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = head
        while let current = ptr {
            let iface = current.pointee
            if iface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: iface.ifa_name)
                if !name.hasPrefix("lo") {
                    if let data = iface.ifa_data {
                        let ifData = data.assumingMemoryBound(to: if_data.self)
                        recv += UInt64(ifData.pointee.ifi_ibytes)
                        xmit += UInt64(ifData.pointee.ifi_obytes)
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return (recv, xmit)
    }

    // MARK: Ping
    // Mirrors latency measurement from src/lib/queries/index.ts (Cloudflare DNS HEAD request)
    private func schedulePingCheck() {
        Task {
            while !Task.isCancelled {
                await measureLatency()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func measureLatency() async {
        guard state == .online else { latency = "--"; return }
        let url = URL(string: "https://1.1.1.1")!
        let start = Date()
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "HEAD"
            req.timeoutInterval = 5
            _ = try await URLSession.shared.data(for: req)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            latency = "\(ms) ms"
        } catch {
            latency = "--"
        }
    }
}
