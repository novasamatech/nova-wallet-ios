import Foundation

enum StakingSharedStateError: Error {
    case missingBlockTimeService
}

final class StakingSharedState {
    let consensus: ConsensusType
    let settings: StakingAssetSettings
    private(set) var eraValidatorService: EraValidatorServiceProtocol?
    private(set) var rewardCalculationService: RewardCalculatorServiceProtocol?
    private(set) var blockTimeService: BlockTimeEstimationServiceProtocol?
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue

    init(
        consensus: ConsensusType,
        settings: StakingAssetSettings,
        eraValidatorService: EraValidatorServiceProtocol?,
        rewardCalculationService: RewardCalculatorServiceProtocol?,
        blockTimeService: BlockTimeEstimationServiceProtocol?,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    ) {
        self.consensus = consensus
        self.settings = settings
        self.eraValidatorService = eraValidatorService
        self.rewardCalculationService = rewardCalculationService
        self.blockTimeService = blockTimeService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.stakingAnalyticsLocalSubscriptionFactory = stakingAnalyticsLocalSubscriptionFactory
        self.operationQueue = operationQueue
    }

    func replaceEraValidatorService(_ newService: EraValidatorServiceProtocol) {
        eraValidatorService = newService
    }

    func replaceRewardCalculatorService(_ newService: RewardCalculatorServiceProtocol) {
        rewardCalculationService = newService
    }

    func replaceBlockTimeService(_ newService: BlockTimeEstimationServiceProtocol?) {
        blockTimeService = newService
    }
}
