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

/// Conformers must use closed value sets or validated content; `String` must never conform to prevent
/// free text from exposing private data.
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
