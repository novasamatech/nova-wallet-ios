import Foundation

final class ParachainStakingSharedState {
    let stakingOption: Multistaking.ChainAssetOption
    private(set) var collatorService: ParachainStakingCollatorServiceProtocol?
    private(set) var rewardCalculationService: ParaStakingRewardCalculatorServiceProtocol?
    private(set) var blockTimeService: BlockTimeEstimationServiceProtocol?
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    init(
        stakingOption: Multistaking.ChainAssetOption,
        collatorService: ParachainStakingCollatorServiceProtocol?,
        rewardCalculationService: ParaStakingRewardCalculatorServiceProtocol?,
        blockTimeService: BlockTimeEstimationServiceProtocol?,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    ) {
        self.stakingOption = stakingOption
        self.collatorService = collatorService
        self.rewardCalculationService = rewardCalculationService
        self.blockTimeService = blockTimeService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
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
