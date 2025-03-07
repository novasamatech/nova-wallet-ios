import Foundation
import SubstrateSdk
import BigInt

extension XcmV3 {
    enum AssetId: Equatable, Codable {
        case concrete(XcmV3.Multilocation)
        case abstract(Data)

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
    }

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

    typealias Fungibility = Xcm.Fungibility

    struct Multiasset: Encodable {
        enum CodingKeys: String, CodingKey {
            case assetId = "id"
            case fun
        }

        let assetId: AssetId
        let fun: Fungibility

        init(multilocation: XcmV3.Multilocation, amount: BigUInt) {
            assetId = .concrete(multilocation)
            fun = .fungible(amount: amount)
        }
    }

    enum MultiassetFilter: Encodable {
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
