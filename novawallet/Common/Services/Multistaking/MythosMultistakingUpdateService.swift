import Foundation
import SubstrateSdk
import Operation_iOS

final class MythosMultistakingUpdateService: ObservableSyncService {
    let accountId: AccountId
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemMythosStakingPart>
    let collatorsOperationFactory: MythosCollatorOperationFactoryProtocol
    let cacheRepository: AnyDataProviderRepository<ChainStorageItem>
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var stateSubscription: CallbackBatchStorageSubscription<Multistaking.MythosStakingStateChange>?

    private var state: Multistaking.MythosStakingState?

    private var saveCallStore = CancellableCallStore()
    private var candidatesCallStore = CancellableCallStore()

    init(
        walletId: MetaAccountModel.Id,
        accountId: AccountId,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemMythosStakingPart>,
        collatorsOperationFactory: MythosCollatorOperationFactoryProtocol,
        cacheRepository: AnyDataProviderRepository<ChainStorageItem>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.walletId = walletId
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.stakingType = stakingType
        self.dashboardRepository = dashboardRepository
        self.collatorsOperationFactory = collatorsOperationFactory
        self.cacheRepository = cacheRepository
        self.connection = connection
        self.runtimeService = runtimeService
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearSubscriptions()
        makeSubscription(for: accountId, chainId: chainAsset.chain.chainId)
    }

    override func stopSyncUp() {
        clearSubscriptions()
    }

    private func clearSubscriptions() {
        stateSubscription?.unsubscribe()
        stateSubscription = nil
    }

    private func makeSubscription(for accountId: AccountId, chainId: ChainModel.Id) {
        do {
            let localKeyFactory = LocalStorageKeyFactory()
            let localKey = try localKeyFactory.createFromStoragePath(
                MythosStakingPallet.userStakePath,
                accountId: accountId,
                chainId: chainId
            )

            let userStakeRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: MythosStakingPallet.userStakePath,
                    localKey: localKey
                ) {
                    BytesCodable(wrappedValue: accountId)
                },
                mappingKey: Multistaking.MythosStakingStateChange.Key.userStake.rawValue
            )

            let freezesRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: BalancesPallet.freezesPath,
                    localKey: ""
                ) {
                    BytesCodable(wrappedValue: accountId)
                },
                mappingKey: Multistaking.MythosStakingStateChange.Key.freezes.rawValue
            )

            let sessionCollatorsRequest = BatchStorageSubscriptionRequest(
                innerRequest: UnkeyedSubscriptionRequest(
                    storagePath: SessionPallet.validatorsPath,
                    localKey: ""
                ),
                mappingKey: Multistaking.MythosStakingStateChange.Key.sessionCollators.rawValue
            )

            stateSubscription = CallbackBatchStorageSubscription(
                requests: [userStakeRequest, freezesRequest, sessionCollatorsRequest],
                connection: connection,
                runtimeService: runtimeService,
                repository: cacheRepository,
                operationQueue: operationQueue,
                callbackQueue: workingQueue
            ) { [weak self] result in
                self?.mutex.lock()

                self?.handleStateChange(result: result)

                self?.mutex.unlock()
            }

            stateSubscription?.subscribe()

        } catch {
            logger.error("Subscription error: \(error)")

            completeImmediate(error)
        }
    }

    private func handleStateChange(result: Result<Multistaking.MythosStakingStateChange, Error>) {
        switch result {
        case let .success(change):
            markSyncingImmediate()

            logger.debug("Change: \(change)")

            guard let state = updateState(from: change) else {
                logger.warning("Broken state detected")
                return
            }

            persistState(state)
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func updateState(from change: Multistaking.MythosStakingStateChange) -> Multistaking.MythosStakingState? {
        if let currentState = state {
            let newState = currentState.applying(change: change)
            state = newState
            return newState
        } else if
            case let .defined(userStake) = change.userStake,
            case let .defined(freezes) = change.freezes,
            case let .defined(sessionCollators) = change.sessionCollators {
            let state = Multistaking.MythosStakingState(
                sessionCollators: sessionCollators,
                userStake: userStake,
                freezes: freezes
            )

            self.state = state

            return state
        } else {
            return nil
        }
    }

    private func persistState(_ state: Multistaking.MythosStakingState) {
        logger.debug("Persisting state: \(state)")

        let stakingOption = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )

        let dashboardItem = Multistaking.DashboardItemMythosStakingPart(
            stakingOption: stakingOption,
            state: state
        )

        let saveOperation = dashboardRepository.saveOperation({
            [dashboardItem]
        }, {
            []
        })

        let wrapper = CompoundOperationWrapper(targetOperation: saveOperation)

        if let pendingOperations = saveCallStore.operatingCall?.allOperations {
            wrapper.addDependency(operations: pendingOperations)
        }

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: saveCallStore,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case .success:
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }
}
