import Foundation

public enum AnalyticsPropertyValue: Equatable {
    case bool(Bool)
    case enumerated(String)
    case content(AnalyticsContentValue)
}

extension AnalyticsPropertyValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .enumerated(value):
            try container.encode(value)
        case let .content(value):
            try container.encode(value.stringValue)
        }
    }
}

/// Conformers are closed value sets or grammar-checked content only. `String` must never conform:
/// free text would carry user data to the gateway.
public protocol AnalyticsPropertyConvertible {
    var analyticsValue: AnalyticsPropertyValue { get }
}

extension Bool: AnalyticsPropertyConvertible {
    public var analyticsValue: AnalyticsPropertyValue { .bool(self) }
}

extension AnalyticsContentValue: AnalyticsPropertyConvertible {
    public var analyticsValue: AnalyticsPropertyValue { .content(self) }
}

public extension AnalyticsPropertyConvertible where Self: RawRepresentable, Self.RawValue == String {
    var analyticsValue: AnalyticsPropertyValue { .enumerated(rawValue) }
}
