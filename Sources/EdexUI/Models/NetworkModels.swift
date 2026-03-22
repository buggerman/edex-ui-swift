import Foundation

struct NetworkTraffic {
    var receiveRate: Double = 0    // bytes/sec
    var transmitRate: Double = 0   // bytes/sec
    var totalReceived: UInt64 = 0  // bytes since boot
    var totalTransmitted: UInt64 = 0
}

struct IPInfo {
    var query: String = ""          // IPv4
    var location: String = ""       // "City, Country"
    var isp: String = ""
    var lat: Double? = nil
    var lon: Double? = nil
    var countryCode: String = ""    // e.g. "CA"
    var region: String = ""         // e.g. "BC"
    var city: String = ""           // e.g. "Vancouver"

    // Abbreviated location string shown in the network panel banner: "CA/BC/Vancouver"
    var locationAbbrev: String {
        guard !countryCode.isEmpty else { return "" }
        return [countryCode, region, city].filter { !$0.isEmpty }.joined(separator: "/")
    }
}

enum NetworkState {
    case online, offline
}
