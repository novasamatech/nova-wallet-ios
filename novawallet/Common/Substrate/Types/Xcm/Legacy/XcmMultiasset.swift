import Foundation
import BigInt
import SubstrateSdk

extension Xcm {
    enum Fungibility: Codable {
        case fungible(amount: BigUInt)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Fungible":
                let amount = try container.decode(StringScaleMapper<Balance>.self).value
                self = .fungible(amount: amount)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported Fungibility type \(type)"
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
            }
        }
    }

    struct Multiasset: Codable {
        enum CodingKeys: String, CodingKey {
            case assetId = "id"
            case fun
        }

        let assetId: Xcm.AssetId
        let fun: Fungibility

        init(multilocation: Xcm.Multilocation, amount: BigUInt) {
            assetId = .concrete(multilocation)
            fun = .fungible(amount: amount)
        }
    }
}
