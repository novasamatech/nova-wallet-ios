import Foundation

struct AnalyticsEventRemote: Codable, Equatable {
    let name: String
    let ts: String
    let props: [String: AnalyticsPropertyValue]
}

enum AnalyticsCoding {
    /// `.sortedKeys` makes the persisted payload and the uploaded envelope reproducible,
    /// which is what lets the byte-stability test compare bytes rather than parsed values.
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder { JSONDecoder() }
}
