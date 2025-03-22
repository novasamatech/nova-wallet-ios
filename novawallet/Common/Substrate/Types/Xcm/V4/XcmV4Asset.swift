import Foundation
import SubstrateSdk
import BigInt

extension XcmV4 {
    typealias AssetId = XcmV4.Multilocation

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
        case other(String, JSON)

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
                let value = try container.decode(JSON.self)
                self = .other(type, value)
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

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .fungible(amount):
                try container.encode("Fungible")
                try container.encode(StringScaleMapper(value: amount))
            case let .nonFungible(assetInstance):
                try container.encode("NonFungible")
                try container.encode(assetInstance)
            }
        }
    }

    struct Multiasset: Codable {
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

    enum AssetFilter: Codable {
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
