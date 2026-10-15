import Foundation
import SubstrateSdk
import Operation_iOS

struct SubtensorEarnServices {
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let earnSettings: SubtensorEarnSettingsProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let recommendationService: SubtensorRecommendationServiceProtocol
    let validatorDirectoryService: SubtensorValidatorDirectoryServiceProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol
    let costBasisService: SubtensorCostBasisServiceProtocol
}

protocol SubtensorStakingSharedStateProtocol: AnyObject {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    var subnetsService: SubtensorSubnetsServiceProtocol { get }
    var apiOperationFactory: SubtensorApiOperationFactoryProtocol { get }
    var earnServices: SubtensorEarnServices { get }
    var flowState: SubtensorStakingFlowStateProtocol { get }

    var selectedAccount: MetaChainAccountResponse? { get }
    var positionsSyncService: SubtensorPositionsSyncServiceProtocol? { get }

    var logger: LoggerProtocol { get }

    func setup(for account: MetaChainAccountResponse?)
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
    let apiOperationFactory: SubtensorApiOperationFactoryProtocol
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let earnServices: SubtensorEarnServices
    let flowState: SubtensorStakingFlowStateProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let novaFeeCalculator: SubtensorNovaFeeCalculator

    private let mutex = NSLock()

    private weak var currentSharedOperation: SharedOperationProtocol?
    private var currentAccount: MetaChainAccountResponse?
    private var currentPositionsSyncService: SubtensorPositionsSyncServiceProtocol?

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        apiOperationFactory: SubtensorApiOperationFactoryProtocol,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        earnServices: SubtensorEarnServices,
        flowState: SubtensorStakingFlowStateProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        novaFeeCalculator: SubtensorNovaFeeCalculator
    ) {
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.subnetsService = subnetsService
        self.apiOperationFactory = apiOperationFactory
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.earnServices = earnServices
        self.flowState = flowState
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
        self.novaFeeCalculator = novaFeeCalculator
    }
}

private extension SubtensorStakingSharedState {
    func setupPositionsSyncService(for accountId: AccountId) {
        let chainId = stakingOption.chainAsset.chain.chainId

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            logger.error("Connection or runtime unavailable for \(chainId)")
            return
        }

        let service = SubtensorStakingPositionsSyncService(
            accountId: accountId,
            stakeStateFetchFactory: stakeStateFetchFactory,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )

        currentPositionsSyncService = service

        service.setup()
    }

    func throttleServices() {
        currentPositionsSyncService?.throttle()
        currentPositionsSyncService = nil

        currentAccount = nil
    }

    var sharedOperation: SharedOperationProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return currentSharedOperation
    }
}

extension SubtensorStakingSharedState: SubtensorStakingSharedStateProtocol {
    var selectedAccount: MetaChainAccountResponse? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return currentAccount
    }

    var positionsSyncService: SubtensorPositionsSyncServiceProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return currentPositionsSyncService
    }

    func setup(for account: MetaChainAccountResponse?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        throttleServices()

        guard let account else {
            return
        }

        currentAccount = account

        setupPositionsSyncService(for: account.chainAccount.accountId)
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        throttleServices()
    }

    func startSharedOperation() -> SharedOperationProtocol {
        let operation = SharedOperation()

        mutex.lock()

        defer {
            mutex.unlock()
        }

        currentSharedOperation = operation

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
            pendingRootClaims: flowState.pendingRootClaims,
            feeCalculator: novaFeeCalculator
        )
    }
}
