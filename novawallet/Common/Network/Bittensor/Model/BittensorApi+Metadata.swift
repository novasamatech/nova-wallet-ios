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

    enum ValueQuality: String, Decodable, Equatable {
        case reported = "REPORTED"
        case derived = "DERIVED"
    }

    enum SourceClass: String, Decodable, Equatable {
        case primary = "PRIMARY"
        case legacy = "LEGACY"
    }

    struct AvailableComponent: Equatable {
        let asOf: Date
        let freshness: Freshness
        let valueQuality: ValueQuality
        let sourceClass: SourceClass
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

    struct SearchRequest: Codable, Equatable {
        let accountSubject: AccountAddress
        let page: Int?
    }

    struct ErrorEnvelope: Decodable, Equatable {
        struct Detail: Decodable, Equatable {
            let code: String
            let message: String
        }

        let error: Detail
    }
}

private enum ComponentCodingKeys: String, CodingKey {
    case availability
    case asOf
    case freshness
    case valueQuality
    case sourceClass
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

        guard let asOf = Self.instant(from: rawAsOf) else {
            throw DecodingError.dataCorruptedError(
                forKey: .asOf,
                in: container,
                debugDescription: "Invalid date-time: \(rawAsOf)"
            )
        }

        self.asOf = asOf
        freshness = try container.decode(BittensorApi.Freshness.self, forKey: .freshness)
        valueQuality = try container.decode(BittensorApi.ValueQuality.self, forKey: .valueQuality)
        sourceClass = try container.decode(BittensorApi.SourceClass.self, forKey: .sourceClass)
    }

    private static func instant(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return formatter.date(from: value)
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
