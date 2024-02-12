import Foundation
import SubstrateSdk
import BigInt

enum HydraStableswap {
    static let module = "Stableswap"

    struct PoolInfo: Decodable {
        let assets: [StringScaleMapper<HydraDx.OmniPoolAssetId>]
        @StringCodable var initialAmplification: BigUInt
        @StringCodable var finalAmplification: BigUInt
        @StringCodable var fee: BigUInt
    }
}
