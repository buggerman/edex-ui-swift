import Foundation

// Mirrors ipInformationQueryOptions in src/lib/queries/index.ts
// Uses ip-api.com exactly as the original does

actor IPInfoService {
    static let shared = IPInfoService()

    private var cached: IPInfo?
    private var lastFetch: Date?
    private let cacheDuration: TimeInterval = 300 // 5 min

    func fetch() async -> IPInfo {
        if let cached, let last = lastFetch, Date().timeIntervalSince(last) < cacheDuration {
            return cached
        }
        do {
            let url = URL(string: "http://ip-api.com/json?fields=query,city,country,countryCode,region,isp,lat,lon")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(IPAPIResponse.self, from: data)
            let info = IPInfo(
                query:       decoded.query,
                location:    "\(decoded.city), \(decoded.country)",
                isp:         decoded.isp,
                lat:         decoded.lat,
                lon:         decoded.lon,
                countryCode: decoded.countryCode,
                region:      decoded.region,
                city:        decoded.city
            )
            cached = info
            lastFetch = Date()
            return info
        } catch {
            return cached ?? IPInfo()
        }
    }

    private struct IPAPIResponse: Decodable {
        var query: String       = ""
        var city: String        = ""
        var country: String     = ""
        var countryCode: String = ""
        var region: String      = ""
        var isp: String         = ""
        var lat: Double?        = nil
        var lon: Double?        = nil
    }
}
