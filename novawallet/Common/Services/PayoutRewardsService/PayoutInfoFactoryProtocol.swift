import Foundation

struct PayoutInfoFactoryParams {
    let unclaimedRewards: StakingUnclaimedReward
    let exposure: StakingValidatorExposure
    let prefs: ValidatorPrefs
    let rewardDistribution: ErasRewardDistribution
    let identities: [AccountAddress: AccountIdentity]
}

protocol PayoutInfoFactoryProtocol {
    func calculate(for accountId: AccountId, params: PayoutInfoFactoryParams) throws -> PayoutInfo?
}
