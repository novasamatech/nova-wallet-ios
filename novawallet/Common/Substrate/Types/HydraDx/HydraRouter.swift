import Foundation
import SubstrateSdk

enum HydraRouter {
    static let moduleName = "Router"

    enum PoolType: Codable {
        static let xykField = "XYK"
        static let lbpField = "LBP"
        static let stableswapField = "Stableswap"
        static let omnipoolField = "Omnipool"
        static let aaveField = "Aave"

        case xyk
        case lbp
        case stableswap(HydraDx.AssetId)
        case omnipool
        case aave

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
            case Self.aaveField:
                self = .aave
            default:
                throw DecodingError.dataCorruptedError(
                    in: unkeyedContainer,
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
            case .aave:
                try unkeyedContainer.encode(Self.aaveField)
                try unkeyedContainer.encode(JSON.null)
            }
        }
    }

    struct Trade: Codable {
        let pool: PoolType
        @StringCodable var assetIn: HydraDx.AssetId
        @StringCodable var assetOut: HydraDx.AssetId
    }
}
