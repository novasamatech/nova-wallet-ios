import Foundation
import SubstrateSdk

enum HydraRouter {
    enum PoolType: Codable {
        static let xykField = "XYK"
        static let lbpField = "LBP"
        static let stableswapField = "Stableswap"
        static let omnipoolField = "Omnipool"

        case xyk
        case lbp
        case stableswap(HydraDx.AssetId)
        case omnipool

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            let type = try unkeyedContainer.decode(String.self)

            switch type {
            case Self.xykField:
                self = .xyk
            case Self.lbpField:
                self = .lbp
            case Self.stableswapField:
                let assetId = try unkeyedContainer.decode(StringScaleMapper<HydraDx.AssetId>.self).value
                self = .stableswap(assetId)
            case Self.omnipoolField:
                self = .omnipool
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "unexpected pool type"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var unkeyedContainer = encoder.unkeyedContainer()

            switch self {
            case .xyk:
                try unkeyedContainer.encode(Self.xykField)
                try unkeyedContainer.encode(JSON.null)
            case .lbp:
                try unkeyedContainer.encode(Self.lbpField)
                try unkeyedContainer.encode(JSON.null)
            case let .stableswap(poolAsset):
                try unkeyedContainer.encode(Self.stableswapField)
                try unkeyedContainer.encode(StringScaleMapper(value: poolAsset))
            case .omnipool:
                try unkeyedContainer.encode(Self.omnipoolField)
                try unkeyedContainer.encode(JSON.null)
            }
        }
    }

    struct Trade: Codable {
        let poolType: PoolType
        @StringCodable var assetId: HydraDx.AssetId
        @StringCodable var assetOut: HydraDx.AssetId
    }
}
