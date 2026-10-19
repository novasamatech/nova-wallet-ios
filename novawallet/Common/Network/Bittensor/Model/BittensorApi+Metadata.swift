import Foundation

enum BittensorApi {}

extension BittensorApi {
    enum Completeness: String, Decodable, Equatable {
        case complete = "COMPLETE"
        case partial = "PARTIAL"
    }

    enum Freshness: String, Decodable, Equatable {
        case fresh = "FRESH"
        case stale = "STALE"
    }

    enum Availability: String, Decodable, Equatable {
        case available = "AVAILABLE"
        case unavailable = "UNAVAILABLE"
    }

    enum AvailabilityReason: String, Decodable, Equatable {
        case temporarilyUnavailable = "temporarily_unavailable"
        case sourceNotSupported = "source_not_supported"
    }

    struct AvailableComponent: Equatable {
        let asOf: Date
        let freshness: Freshness
    }

    enum ComponentMetadata: Equatable {
        case available(AvailableComponent)
        case unavailable(AvailabilityReason)
    }

    struct PageInfo: Decodable, Equatable {
        let page: Int
        let pageSize: Int
        let total: Int
        let nextPage: Int?
    }
}

private enum ComponentCodingKeys: String, CodingKey {
    case availability
    case asOf
    case freshness
    case availabilityReason
}

extension BittensorApi.AvailableComponent: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ComponentCodingKeys.self)

        guard try container.decode(BittensorApi.Availability.self, forKey: .availability) == .available else {
            throw DecodingError.dataCorruptedError(
                forKey: .availability,
                in: container,
                debugDescription: "Component must be available"
            )
        }

        let rawAsOf = try container.decode(String.self, forKey: .asOf)

        guard let asOf = BittensorApi.instant(from: rawAsOf) else {
            throw DecodingError.dataCorruptedError(
                forKey: .asOf,
                in: container,
                debugDescription: "Invalid date-time: \(rawAsOf)"
            )
        }

        self.asOf = asOf
        freshness = try container.decode(BittensorApi.Freshness.self, forKey: .freshness)
    }
}

extension BittensorApi {
    private static let instantFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalInstantFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func instant(from value: String) -> Date? {
        instantFormatter.date(from: value) ?? fractionalInstantFormatter.date(from: value)
    }
}

extension BittensorApi.ComponentMetadata: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ComponentCodingKeys.self)

        switch try container.decode(BittensorApi.Availability.self, forKey: .availability) {
        case .available:
            self = .available(try BittensorApi.AvailableComponent(from: decoder))
        case .unavailable:
            self = .unavailable(
                try container.decode(BittensorApi.AvailabilityReason.self, forKey: .availabilityReason)
            )
        }
    }
}
