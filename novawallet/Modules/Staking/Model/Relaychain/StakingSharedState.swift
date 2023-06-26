import Foundation

enum StakingSharedStateError: Error {
    case missingBlockTimeService
}

final class StakingSharedState {
    let consensus: ConsensusType
    let stakingOption: Multistaking.ChainAssetOption
    private(set) var eraValidatorService: EraValidatorServiceProtocol?
    private(set) var rewardCalculationService: RewardCalculatorServiceProtocol?
    private(set) var blockTimeService: BlockTimeEstimationServiceProtocol?
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue

    init(
        consensus: ConsensusType,
        stakingOption: Multistaking.ChainAssetOption,
        eraValidatorService: EraValidatorServiceProtocol?,
        rewardCalculationService: RewardCalculatorServiceProtocol?,
        blockTimeService: BlockTimeEstimationServiceProtocol?,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    ) {
        self.consensus = consensus
        self.stakingOption = stakingOption
        self.eraValidatorService = eraValidatorService
        self.rewardCalculationService = rewardCalculationService
        self.blockTimeService = blockTimeService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
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
