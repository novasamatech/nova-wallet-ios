import Foundation

final class ParachainStakingSharedState {
    let settings: StakingAssetSettings
    private(set) var collatorService: ParachainStakingCollatorServiceProtocol?
    private(set) var rewardCalculationService: ParaStakingRewardCalculatorServiceProtocol?
    private(set) var blockTimeService: BlockTimeEstimationServiceProtocol?
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol

    init(
        settings: StakingAssetSettings,
        collatorService: ParachainStakingCollatorServiceProtocol?,
        rewardCalculationService: ParaStakingRewardCalculatorServiceProtocol?,
        blockTimeService: BlockTimeEstimationServiceProtocol?,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    ) {
        self.settings = settings
        self.collatorService = collatorService
        self.rewardCalculationService = rewardCalculationService
        self.blockTimeService = blockTimeService
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

    func replaceBlockTimeService(_ newService: BlockTimeEstimationServiceProtocol) {
        blockTimeService = newService
    }
}
