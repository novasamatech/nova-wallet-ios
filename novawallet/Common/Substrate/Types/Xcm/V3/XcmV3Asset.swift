import Foundation
import SubstrateSdk
import BigInt

extension XcmV3 {
    enum AssetId: Equatable, Codable {
        case concrete(XcmV3.Multilocation)
        case abstract(Data)

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Concrete":
                let multilocation = try container.decode(XcmV3.Multilocation.self)
                self = .concrete(multilocation)
            case "Abstract":
                let data = try container.decode(BytesCodable.self).wrappedValue
                self = .abstract(data)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unsupported type: \(type)"
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

    typealias Fungibility = Xcm.Fungibility

    struct Multiasset: Codable {
        enum CodingKeys: String, CodingKey {
            case assetId = "id"
            case fun
        }

        let assetId: AssetId
        let fun: Fungibility

        init(multilocation: XcmV3.Multilocation, amount: BigUInt) {
            assetId = .concrete(multilocation)

            // starting from xcmV3 zero amount is prohibited
            fun = .fungible(amount: max(amount, 1))
        }
    }

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
