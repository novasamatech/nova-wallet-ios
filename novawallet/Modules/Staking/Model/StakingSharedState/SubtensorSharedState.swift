import Foundation
import SubstrateSdk
import Operation_iOS

struct SubtensorEarnServices {
    let subnetLogosProvider: SubtensorConfigProviding
    let earnSettings: SubtensorEarnSettingsProtocol
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let alphaPriceOperationFactory: SubtensorAlphaPriceOperationFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let maxApyOperationFactory: SubtensorMaxApyOperationFactoryProtocol
    let recommendationOperationFactory: SubtensorRecommendationOperationFactoryProtocol
    let validatorDirectoryOperationFactory: SubtensorValidatorDirectoryOperationFactoryProtocol
    let priceHistoryOperationFactory: SubtensorPriceHistoryOperationFactoryProtocol?
    let tradeQuoteOperationFactory: SubtensorTradeQuoteOperationFactoryProtocol
    let rootHoldOperationFactory: SubtensorRootHoldOperationFactoryProtocol
    let groupHotkeyOperationFactory: SubtensorGroupHotkeyOperationFactoryProtocol
    let validatorPresetOperationFactory: SubtensorValidatorPresetOperationFactoryProtocol
    let costBasisService: SubtensorCostBasisServiceProtocol
}

protocol SubtensorSharedStateProtocol: AnyObject {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    var subnetsOperationFactory: SubtensorSubnetsOperationFactoryProtocol { get }
    var apiOperationFactory: SubtensorApiOperationFactoryProtocol { get }
    var earnServices: SubtensorEarnServices { get }
    var flowState: SubtensorFlowStateProtocol { get }

    var selectedAccount: MetaChainAccountResponse? { get }
    var positionsSyncService: SubtensorPositionsSyncServiceProtocol? { get }

    var logger: LoggerProtocol { get }

    func setup(for account: MetaChainAccountResponse?)
    func throttle()
    func startSharedOperation() -> SharedOperationProtocol

    func createSubmissionOperationFactory(
        for accountId: AccountId,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        shield: SubtensorShieldServices?
    ) throws -> SubtensorSubmissionOperationFactoryProtocol
}

final class SubtensorSharedState {
    let stakingOption: Multistaking.ChainAssetOption
    let chainRegistry: ChainRegistryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let subnetsOperationFactory: SubtensorSubnetsOperationFactoryProtocol
    let apiOperationFactory: SubtensorApiOperationFactoryProtocol
    let stakeStateSourceFactory: SubtensorStakeStateSourceFactoryProtocol
    let earnServices: SubtensorEarnServices
    let flowState: SubtensorFlowStateProtocol
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
        subnetsOperationFactory: SubtensorSubnetsOperationFactoryProtocol,
        apiOperationFactory: SubtensorApiOperationFactoryProtocol,
        stakeStateSourceFactory: SubtensorStakeStateSourceFactoryProtocol,
        earnServices: SubtensorEarnServices,
        flowState: SubtensorFlowStateProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol,
        novaFeeCalculator: SubtensorNovaFeeCalculator
    ) {
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.subnetsOperationFactory = subnetsOperationFactory
        self.apiOperationFactory = apiOperationFactory
        self.stakeStateSourceFactory = stakeStateSourceFactory
        self.earnServices = earnServices
        self.flowState = flowState
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
        self.novaFeeCalculator = novaFeeCalculator
    }
}

private extension SubtensorSharedState {
    func setupPositionsSyncService(for accountId: AccountId) {
        guard let stakeStateSource = stakeStateSourceFactory.getSource(
            for: accountId,
            chainAsset: stakingOption.chainAsset,
            chainRegistry: chainRegistry
        ) else {
            logger.error("Connection or runtime unavailable for \(stakingOption.chainAsset.chain.chainId)")
            return
        }

        let service = SubtensorPositionsSyncService(
            stakeStateSource: stakeStateSource,
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

extension SubtensorSharedState: SubtensorSharedStateProtocol {
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

    func createSubmissionOperationFactory(
        for accountId: AccountId,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        shield: SubtensorShieldServices?
    ) throws -> SubtensorSubmissionOperationFactoryProtocol {
        let chainId = stakingOption.chainAsset.chain.chainId

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        return SubtensorSubmissionOperationFactory(
            chainAsset: stakingOption.chainAsset,
            accountId: accountId,
            extrinsicService: extrinsicService,
            extrinsicSubmitMonitor: extrinsicSubmitMonitor,
            signer: signer,
            runtimeProvider: runtimeProvider,
            sharedOperation: sharedOperation,
            eventCenter: eventCenter,
            configProvider: earnServices.subnetLogosProvider,
            pendingRootClaims: flowState.pendingRootClaims,
            feeCalculator: novaFeeCalculator,
            shield: shield
        )
    }
}
