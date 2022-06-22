import Foundation
import BigInt
import SubstrateSdk

extension Xcm {
    enum Fungibility: Encodable {
        case fungible(amount: BigUInt)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .fungible(amount):
                try container.encode("Fungible")
                try container.encode(StringScaleMapper(value: amount))
            }
        }
    }

    struct Multiasset: Encodable {
        // swiftlint:disable:next nesting
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
