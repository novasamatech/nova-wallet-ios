import Foundation

struct AnalyticsEventRemote: Codable, Equatable {
    let name: String
    let ts: String
    let props: [String: AnalyticsPropertyValue]
}

enum AnalyticsCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder { JSONDecoder() }
}
