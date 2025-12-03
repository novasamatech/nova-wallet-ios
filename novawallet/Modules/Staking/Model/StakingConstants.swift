import Foundation

struct StakingConstants {
    static let targetsClusterLimit = 2
    static let feeEstimation: Decimal = 1e+7
    static let maxUnlockingChunks: UInt32 = 32

    static let recommendedPoolIds: [ChainModel.Id: NominationPools.PoolId] = [
        KnowChainId.polkadotAssetHub: 54,
        KnowChainId.kusamaAssetHub: 160,
        KnowChainId.alephZero: 74,
        KnowChainId.vara: 65,
        KnowChainId.avail: 3
    ]
}
