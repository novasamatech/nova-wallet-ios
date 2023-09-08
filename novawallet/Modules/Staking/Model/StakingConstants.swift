import Foundation

struct StakingConstants {
    static let targetsClusterLimit = 2
    static let maxAmount: Decimal = 1e+7
    static let maxUnlockingChunks: UInt32 = 32

    static let recommendedPoolIds: [ChainModel.Id: NominationPools.PoolId] = [
        KnowChainId.polkadot: 54,
        KnowChainId.kusama: 160,
        KnowChainId.alephZero: 74
    ]

    static let recommendedValidators: [ChainModel.Id: AccountAddress] = [
        KnowChainId.polkadot: "127zarPDhVzmCXVQ7Kfr1yyaa9wsMuJ74GJW9Q7ezHfQEgh6",
        KnowChainId.kusama: "DhK6qU2U5kDWeJKvPRtmnWRs8ETUGZ9S9QmNmQFuzrNoKm4",
        KnowChainId.alephZero: "5DBhSX89qijHkzUt9gcqsq9RiXxDfbjxyma1z78JSCdt4SoU"
    ]
}
