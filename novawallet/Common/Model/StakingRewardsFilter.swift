import RobinHood

struct StakingRewardsFilter: Identifiable {
    let chainAccountId: AccountId
    let chainAssetId: ChainAssetId
    let stakingType: StakingType
    let period: StakingRewardFiltersPeriod

    var identifier: String {
        StakingRewardsFilter.createIdentifier(
            chainAccountId: chainAccountId,
            chainAssetId: chainAssetId,
            stakingType: stakingType
        )
    }

    static func createIdentifier(
        chainAccountId: AccountId,
        chainAssetId: ChainAssetId,
        stakingType: StakingType
    ) -> String {
        [
            chainAccountId.toHexString(),
            chainAssetId.stringValue,
            stakingType.rawValue
        ].joined(separator: "-")
    }
}
