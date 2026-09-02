import Foundation

/// The closed set of free-form strings analytics may carry. There is deliberately no case
/// for an address, an account id, a raw amount, a payload or an error message.
enum AnalyticsContentValue: Equatable {
    case assetSymbol(String)
    case networkName(String)
    case dappHost(String)
    case providerId(String)
    case bannerId(String)
    case signingMethod(String)
    case caip2Chain(String)
    /// Produced only by decoding a persisted row. No factory creates it.
    case raw(String)

    var stringValue: String {
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

enum AnalyticsPropertyValue: Equatable {
    case bool(Bool)
    case int(Int)
    case enumerated(String)
    case content(AnalyticsContentValue)
}

extension AnalyticsPropertyValue: Codable {
    /// Explicit, because the synthesized conformance emits the keyed {"bool":{"_0":true}}
    /// shape and could never decode a row written as a JSON primitive.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .content(.raw(try container.decode(String.self)))
        }
    }

    func encode(to encoder: Encoder) throws {
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

protocol AnalyticsPropertyConvertible {
    var analyticsValue: AnalyticsPropertyValue { get }
}

extension Bool: AnalyticsPropertyConvertible {
    var analyticsValue: AnalyticsPropertyValue { .bool(self) }
}

extension Int: AnalyticsPropertyConvertible {
    var analyticsValue: AnalyticsPropertyValue { .int(self) }
}

extension AnalyticsContentValue: AnalyticsPropertyConvertible {
    var analyticsValue: AnalyticsPropertyValue { .content(self) }
}

extension AnalyticsPropertyConvertible where Self: RawRepresentable, Self.RawValue == String {
    var analyticsValue: AnalyticsPropertyValue { .enumerated(rawValue) }
}

// String deliberately does NOT conform. This is the privacy boundary — adding a
// `extension String: AnalyticsPropertyConvertible` would defeat the whole design.
