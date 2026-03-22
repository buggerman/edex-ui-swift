import Foundation

struct NetworkTraffic {
    var receiveRate: Double = 0    // bytes/sec
    var transmitRate: Double = 0   // bytes/sec
    var totalReceived: UInt64 = 0  // bytes since boot
    var totalTransmitted: UInt64 = 0
}

struct IPInfo {
    var query: String = ""      // IPv4
    var location: String = ""   // "City, Country"
    var isp: String = ""
}

enum NetworkState {
    case online, offline
}
