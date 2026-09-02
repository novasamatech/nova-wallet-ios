import Foundation

struct AnalyticsEvent: Equatable {
    let name: AnalyticsEventName
    let properties: [AnalyticsPropertyKey: AnalyticsPropertyValue]

    /// A nil value omits its key entirely — the wire never carries an explicit null.
    init(
        name: AnalyticsEventName,
        properties: [AnalyticsPropertyKey: AnalyticsPropertyConvertible?] = [:]
    ) {
        self.name = name
        self.properties = properties.compactMapValues { $0?.analyticsValue }
    }

    var wireProperties: [String: AnalyticsPropertyValue] {
        Dictionary(uniqueKeysWithValues: properties.map { ($0.key.rawValue, $0.value) })
    }
}
