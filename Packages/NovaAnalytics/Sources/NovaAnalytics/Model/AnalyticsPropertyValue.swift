import Foundation

public enum AnalyticsContentValue: Equatable {
    case assetSymbol(String)
    case networkName(String)
    case dappHost(String)
    case providerId(String)
    case bannerId(String)
    case signingMethod(String)
    case caip2Chain(String)
    case raw(String)

    public var stringValue: String {
        switch self {
        case let .assetSymbol(value),
             let .networkName(value),
             let .dappHost(value),
             let .providerId(value),
             let .bannerId(value),
             let .signingMethod(value),
             let .caip2Chain(value),
             let .raw(value):
            value
        }
    }
}

public enum AnalyticsPropertyValue: Equatable {
    case bool(Bool)
    case int(Int)
    case enumerated(String)
    case content(AnalyticsContentValue)
}

extension AnalyticsPropertyValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .enumerated(value):
            try container.encode(value)
        case let .content(value):
            try container.encode(value.stringValue)
        }
    }
}

/// Conformers are closed value sets only. `String` must never conform: free text would carry
/// user data to the gateway.
public protocol AnalyticsPropertyConvertible {
    var analyticsValue: AnalyticsPropertyValue { get }
}

extension Bool: AnalyticsPropertyConvertible {
    public var analyticsValue: AnalyticsPropertyValue { .bool(self) }
}

extension Int: AnalyticsPropertyConvertible {
    public var analyticsValue: AnalyticsPropertyValue { .int(self) }
}

extension AnalyticsContentValue: AnalyticsPropertyConvertible {
    public var analyticsValue: AnalyticsPropertyValue { .content(self) }
}

public extension AnalyticsPropertyConvertible where Self: RawRepresentable, Self.RawValue == String {
    var analyticsValue: AnalyticsPropertyValue { .enumerated(rawValue) }
}
