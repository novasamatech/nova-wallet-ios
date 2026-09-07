import Foundation

public struct AnalyticsEvent: Equatable {
    public let name: AnalyticsEventName
    public let properties: [AnalyticsPropertyKey: AnalyticsPropertyValue]

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
