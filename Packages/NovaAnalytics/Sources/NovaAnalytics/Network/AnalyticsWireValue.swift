import Foundation

/// What a stored payload decodes to. `int` stays decodable although the catalogue no longer emits
/// one, so a numeric value in an older row ships instead of poisoning it.
enum AnalyticsWireValue: Equatable {
    case bool(Bool)
    case int(Int)
    case string(String)
}

extension AnalyticsWireValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        }
    }
}
