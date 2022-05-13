import Foundation

final class ParachainStakingSharedState {
    let settings: StakingAssetSettings
    private(set) var collatorService: ParachainStakingCollatorServiceProtocol?
    private(set) var rewardCalculationService: ParaStakingRewardCalculatorServiceProtocol?
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol

    init(
        settings: StakingAssetSettings,
        collatorService: ParachainStakingCollatorServiceProtocol?,
        rewardCalculationService _: RewardCalculatorServiceProtocol?,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    ) {
        self.settings = settings
        self.collatorService = collatorService
        self.collatorService = collatorService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
    }

    func replaceCollatorService(_ newService: ParachainStakingCollatorServiceProtocol) {
        collatorService = newService
    }

    func replaceRewardCalculatorService(
        _ newService: ParaStakingRewardCalculatorServiceProtocol
    ) {
        rewardCalculationService = newService
    }
}
