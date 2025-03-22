import Foundation
import SubstrateSdk

extension Xcm {
    enum AssetId: Codable {
        case concrete(Multilocation)
        case abstract(Data)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Concrete":
                let multilocation = try container.decode(Multilocation.self)
                self = .concrete(multilocation)
            case "Abstract":
                let data = try container.decode(BytesCodable.self).wrappedValue
                self = .abstract(data)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported asset id type \(type)"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .concrete(multilocation):
                try container.encode("Concrete")
                try container.encode(multilocation)
            case let .abstract(data):
                try container.encode("Abstract")
                try container.encode(BytesCodable(wrappedValue: data))
            }
        }
    }

    enum WildFungibility: Int, Codable {
        case fungible
        case nonFungible

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let rawValue = try container.decode(Int.self)

            guard let fung = WildFungibility(rawValue: rawValue) else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unsuppored wild fungibility \(rawValue)"
                    )
                )
            }

            self = fung
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(rawValue)
        }
    }

    enum WildMultiasset: Codable {
        struct AllOfValue: Codable {
            enum CodingKeys: String, CodingKey {
                case assetId = "id"
                case fun
            }

            let assetId: AssetId
            let fun: WildFungibility
        }

        case all
        case allOf(AllOfValue)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "All":
                self = .all
            case "AllOf":
                let value = try container.decode(AllOfValue.self)
                self = .allOf(value)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unsuppored wild multiasset \(type)"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .all:
                try container.encode("All")
                try container.encode(JSON.null)
            case let .allOf(value):
                try container.encode("AllOf")
                try container.encode(value)
            }
        }
    }

    // swiftlint:enable nesting

    enum MultiassetFilter: Codable {
        case definite([Multiasset])
        case wild(WildMultiasset)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Definite":
                let value = try container.decode([Multiasset].self)
                self = .definite(value)
            case "Wild":
                let value = try container.decode(WildMultiasset.self)
                self = .wild(value)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unsupported filter \(type)"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .definite(multiassets):
                try container.encode("Definite")
                try container.encode(multiassets)
            case let .wild(wildMultiasset):
                try container.encode("Wild")
                try container.encode(wildMultiasset)
            }
        }
    }
}
