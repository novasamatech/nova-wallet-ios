import RobinHood
import Foundation

protocol ParachainStakingStateFactoryProtocol {
    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    func createState() throws -> ParachainStakingSharedState
}

final class ParachainStakingStateFactory: ParachainStakingStateFactoryProtocol {
    private let chainRegistry: ChainRegistryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let logger: LoggerProtocol
    private let stakingOption: Multistaking.ChainAssetOption
    private let eventCenter: EventCenterProtocol
    private let operationQueue: OperationQueue
    private let operationManager: OperationManagerProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        let operationManager = OperationManager(operationQueue: operationQueue)
        stakingLocalSubscriptionFactory = ParachainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
        generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        self.operationManager = operationManager
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func createState() throws -> ParachainStakingSharedState {
        let stakingServiceFactory = ParachainStakingServiceFactory(
            stakingProviderFactory: stakingLocalSubscriptionFactory,
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        let chainAsset = stakingOption.chainAsset
        let chainId = chainAsset.chain.chainId
        let collatorsService = try stakingServiceFactory.createSelectedCollatorsService(
            for: chainId
        )
        let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
            for: chainId,
            stakingType: chainAsset.asset.stakings?.first ?? .unsupported,
            assetPrecision: Int16(chainAsset.asset.precision),
            collatorService: collatorsService
        )
        let blockTimeService = try stakingServiceFactory.createBlockTimeService(
            for: chainId
        )

        return ParachainStakingSharedState(
            stakingOption: stakingOption,
            collatorService: collatorsService,
            rewardCalculationService: rewardCalculatorService,
            blockTimeService: blockTimeService,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory
        )
    }
}
