import Foundation
import SubstrateSdk
import BigInt

extension XcmV4 {
    typealias AssetId = XcmV4.Multilocation

    enum WildFungibility: Int, Encodable {
        case fungible
        case nonFungible

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(rawValue)
        }
    }

    enum WildMultiasset: Encodable {
        struct AllOfValue: Encodable {
            enum CodingKeys: String, CodingKey {
                case assetId = "id"
                case fun
            }

            let assetId: AssetId
            let fun: WildFungibility
        }

        case all
        case allOf(AllOfValue)
        case other(String, JSON)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .all:
                try container.encode("All")
                try container.encode(JSON.null)
            case let .allOf(value):
                try container.encode("AllOf")
                try container.encode(value)
            case let .other(type, value):
                try container.encode(type)
                try container.encode(value)
            }
        }
    }

    typealias AssetInstance = JSON

    enum Fungibility: Codable {
        case fungible(Balance)
        case nonFungible(AssetInstance)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Fungible":
                let amount = try container.decode(StringScaleMapper<Balance>.self).value
                self = .fungible(amount)
            case "NonFungible":
                let assetInstance = try container.decode(AssetInstance.self)
                self = .nonFungible(assetInstance)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unknown fungibility \(type)"
                    )
                )
            }
        }
    }

    struct Multiasset: Encodable {
        enum CodingKeys: String, CodingKey {
            case assetId = "id"
            case fun
        }

        let assetId: AssetId
        let fun: Fungibility

        init(assetId: AssetId, amount: BigUInt) {
            self.assetId = assetId

            // starting from xcmV3 zero amount is prohibited
            fun = .fungible(max(amount, 1))
        }
    }

    enum AssetFilter: Encodable {
        case definite([Multiasset])
        case wild(WildMultiasset)

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
