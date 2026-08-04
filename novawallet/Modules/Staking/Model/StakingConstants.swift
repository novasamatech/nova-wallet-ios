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

    // Chains where the user is placed in Nova's pool and cannot pick another one.
    // Every entry must also appear in recommendedPoolIds — see StakingConstantsTests.
    static let forcedPoolChainIds: Set<ChainModel.Id> = [
        KnowChainId.polkadotAssetHub,
        KnowChainId.kusamaAssetHub
    ]

    static func isPoolForced(for chainId: ChainModel.Id) -> Bool {
        forcedPoolChainIds.contains(chainId)
    }
}
