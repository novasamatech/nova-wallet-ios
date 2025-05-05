import Foundation
import SubstrateSdk
import BigInt
import NovaCrypto

enum HydraStableswap {
    static let module = "Stableswap"

    struct PoolPair: Equatable, Hashable {
        let poolAsset: HydraDx.AssetId
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
    }

    struct PoolInfo: Decodable {
        let assets: [StringScaleMapper<HydraDx.AssetId>]
        @StringCodable var initialAmplification: BigUInt
        @StringCodable var finalAmplification: BigUInt
        @StringCodable var initialBlock: BlockNumber
        @StringCodable var finalBlock: BlockNumber
        @StringCodable var fee: BigUInt
    }

    struct Tradability: Decodable {
        @StringCodable var bits: UInt8

        func matches(flags: UInt8) -> Bool {
            (bits & flags) == flags
        }

        func canSell() -> Bool {
            matches(flags: 1 << 0)
        }

        func canBuy() -> Bool {
            matches(flags: 1 << 1)
        }

        func canAddLiquidity() -> Bool {
            matches(flags: 1 << 2)
        }

        func canRemoveLiquidity() -> Bool {
            matches(flags: 1 << 3)
        }
    }

    static func poolAccountId(for asset: HydraDx.AssetId) throws -> AccountId {
        guard let accountIdPrefix = "sts".data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let data = accountIdPrefix + Data(UInt32(asset).littleEndianBytes)

        return try data.blake2b32()
    }
}
