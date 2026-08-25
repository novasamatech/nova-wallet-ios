import Foundation
import SubstrateSdk
import Operation_iOS

protocol SubtensorStakingSharedStateProtocol: AnyObject {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    var subnetsService: SubtensorSubnetsServiceProtocol { get }
    var delegatesService: SubtensorDelegatesServiceProtocol { get }
    var apiOperationFactory: SubtensorApiOperationFactoryProtocol { get }

    var positionsSyncService: SubtensorPositionsSyncServiceProtocol? { get }
    var rootClaimableService: SubtensorRootClaimableServiceProtocol? { get }

    var logger: LoggerProtocol { get }

    var sharedOperation: SharedOperationProtocol? { get }

    func setup(for accountId: AccountId?)
    func throttle()
    func startSharedOperation() -> SharedOperationProtocol
}

final class SubtensorStakingSharedState {
    let stakingOption: Multistaking.ChainAssetOption
    let chainRegistry: ChainRegistryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let delegatesService: SubtensorDelegatesServiceProtocol
    let apiOperationFactory: SubtensorApiOperationFactoryProtocol
    let stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    weak var sharedOperation: SharedOperationProtocol?

    private(set) var positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    private(set) var rootClaimableService: SubtensorRootClaimableServiceProtocol?

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        delegatesService: SubtensorDelegatesServiceProtocol,
        apiOperationFactory: SubtensorApiOperationFactoryProtocol,
        stakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.subnetsService = subnetsService
        self.delegatesService = delegatesService
        self.apiOperationFactory = apiOperationFactory
        self.stakeStateFetchFactory = stakeStateFetchFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
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

        let service = SubtensorStakingPositionsSyncService(
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
}
