import Foundation
import SubstrateSdk
import Operation_iOS

struct SubtensorEarnServices {
    let earnConfigProvider: SubtensorEarnConfigProviderProtocol
    let earnSettings: SubtensorEarnSettingsProtocol
    let validatorChainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let recommendationService: SubtensorRecommendationServiceProtocol
    let validatorDirectoryService: SubtensorValidatorDirectoryServiceProtocol
    let discoveryService: SubtensorDiscoveryServiceProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol
}

protocol SubtensorStakingSharedStateProtocol: AnyObject {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    var subnetsService: SubtensorSubnetsServiceProtocol { get }
    var delegatesService: SubtensorDelegatesServiceProtocol { get }
    var rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol { get }
    var apiOperationFactory: SubtensorApiOperationFactoryProtocol { get }
    var earnServices: SubtensorEarnServices { get }

    var positionsSyncService: SubtensorPositionsSyncServiceProtocol? { get }
    var rootClaimableService: SubtensorRootClaimableServiceProtocol? { get }

    var logger: LoggerProtocol { get }

    var sharedOperation: SharedOperationProtocol? { get }

    func setup(for accountId: AccountId?)
    func throttle()
    func startSharedOperation() -> SharedOperationProtocol

    func createStakingOperationService(
        for accountId: AccountId,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol
    ) throws -> SubtensorStakingOperationServiceProtocol
}

final class SubtensorStakingSharedState {
    let stakingOption: Multistaking.ChainAssetOption
    let chainRegistry: ChainRegistryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let delegatesService: SubtensorDelegatesServiceProtocol
    let rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol
    let apiOperationFactory: SubtensorApiOperationFactoryProtocol
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let earnServices: SubtensorEarnServices
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let novaFeeCalculator: SubtensorNovaFeeCalculator
    let positionsSyncServiceFactory: ((AccountId) -> SubtensorPositionsSyncServiceProtocol)?

    weak var sharedOperation: SharedOperationProtocol?

    private(set) var positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    private(set) var rootClaimableService: SubtensorRootClaimableServiceProtocol?

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        delegatesService: SubtensorDelegatesServiceProtocol,
        rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol,
        apiOperationFactory: SubtensorApiOperationFactoryProtocol,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        earnServices: SubtensorEarnServices,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        novaFeeCalculator: SubtensorNovaFeeCalculator,
        positionsSyncServiceFactory: ((AccountId) -> SubtensorPositionsSyncServiceProtocol)?
    ) {
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.subnetsService = subnetsService
        self.delegatesService = delegatesService
        self.rewardCalculatorService = rewardCalculatorService
        self.apiOperationFactory = apiOperationFactory
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.earnServices = earnServices
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
        self.novaFeeCalculator = novaFeeCalculator
        self.positionsSyncServiceFactory = positionsSyncServiceFactory
    }
}

private extension SubtensorStakingSharedState {
    func setupPositionsSyncService(
        for accountId: AccountId
    ) -> SubtensorPositionsSyncServiceProtocol? {
        let chainId = stakingOption.chainAsset.chain.chainId

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger.error("Connection or runtime unavailable for \(chainId)")
            return nil
        }

        let service = positionsSyncServiceFactory?(accountId) ?? SubtensorStakingPositionsSyncService(
            accountId: accountId,
            stakeStateFetchFactory: stakeStateFetchFactory,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )

        positionsSyncService = service

        service.setup()

        return service
    }

    func setupRootClaimableService(
        for accountId: AccountId,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol
    ) {
        let service = SubtensorRootClaimableService(
            coldkey: accountId,
            positionsSyncService: positionsSyncService,
            operationFactory: apiOperationFactory,
            operationQueue: operationQueue
        )

        rootClaimableService = service

        service.setup()
    }
}

extension SubtensorStakingSharedState: SubtensorStakingSharedStateProtocol {
    func setup(for accountId: AccountId?) {
        guard let accountId else {
            return
        }

        if let positionsService = setupPositionsSyncService(for: accountId) {
            setupRootClaimableService(
                for: accountId,
                positionsSyncService: positionsService
            )
        }
    }

    func throttle() {
        rootClaimableService?.throttle()
        rootClaimableService = nil

        positionsSyncService?.throttle()
        positionsSyncService = nil
    }

    func startSharedOperation() -> SharedOperationProtocol {
        let operation = SharedOperation()
        sharedOperation = operation
        return operation
    }

    func createStakingOperationService(
        for accountId: AccountId,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol
    ) throws -> SubtensorStakingOperationServiceProtocol {
        let chainId = stakingOption.chainAsset.chain.chainId

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        return SubtensorStakingOperationService(
            chainAsset: stakingOption.chainAsset,
            accountId: accountId,
            extrinsicService: extrinsicService,
            extrinsicSubmitMonitor: extrinsicSubmitMonitor,
            signer: signer,
            runtimeProvider: runtimeProvider,
            positionsSyncService: positionsSyncService,
            sharedOperation: sharedOperation,
            eventCenter: eventCenter,
            feeCalculator: novaFeeCalculator
        )
    }
}
