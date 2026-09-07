import Foundation

struct AnalyticsEventRemote: Codable, Equatable {
    let id: String
    let name: String
    let timestamp: String
    let props: [String: AnalyticsPropertyValue]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case timestamp = "ts"
        case props
    }
}

enum AnalyticsCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder { JSONDecoder() }
}
