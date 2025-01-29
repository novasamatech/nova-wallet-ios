import Foundation
import SubstrateSdk
import Operation_iOS

protocol MythosStakingIdentitiesSyncServiceProtocol: ApplicationServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<[AccountId: AccountIdentity]>.StateChangeClosure
    )

    func remove(observer: AnyObject)
}

final class MythosStakingIdentitiesSyncService: BaseSyncService, AnyProviderAutoCleaning {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let operationFactory: IdentityProxyFactoryProtocol
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    private let callStore = CancellableCallStore()

    private var stateObservable: Observable<[AccountId: AccountIdentity]> = .init(state: [:])
    private var userStakeProvider: AnyDataProvider<MythosStakingPallet.DecodedUserStake>?
    private var collatorIds: [AccountId]?

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        operationFactory: IdentityProxyFactoryProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global()
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.workQueue = workQueue
    }

    deinit {
        userStakeProvider = nil
        callStore.cancel()
    }

    private func updateState() {
        guard let collatorIds, !collatorIds.isEmpty else {
            stateObservable.state = [:]
            completeImmediate(nil)
            return
        }

        let wrapper = operationFactory.createIdentityWrapperByAccountId { collatorIds }

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.logger.debug("New state: \(model)")

                self?.stateObservable.state = model
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.logger.error("Error: \(error)")
                self?.completeImmediate(error)
            }
        }
    }

    private func updateIfNotInProgress() {
        guard !callStore.hasCall else {
            return
        }

        markSyncingImmediate()
        updateState()
    }

    private func clearSubscriptionAndRequest() {
        clear(dataProvider: &userStakeProvider)

        callStore.cancel()
    }

    private func setupSubscription(for chainId: ChainModel.Id, accountId: AccountId) {
        userStakeProvider = subscribeToUserState(for: chainId, accountId: accountId)
    }

    override func performSyncUp() {
        if userStakeProvider == nil {
            clearSubscriptionAndRequest()
            setupSubscription(for: chainId, accountId: accountId)
        } else {
            callStore.cancel()
            updateState()
        }
    }

    override func stopSyncUp() {
        clearSubscriptionAndRequest()
    }
}

extension MythosStakingIdentitiesSyncService: MythosStakingLocalStorageSubscriber,
    MythosStakingLocalStorageHandler {
    func handleUserStake(
        result: Result<MythosStakingPallet.UserStake?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case let .success(stakingState):
            logger.debug("Staking state: \(String(describing: stakingState))")

            let newCollatorIds = stakingState?.candidates.map(\.wrappedValue)

            if collatorIds != newCollatorIds {
                collatorIds = newCollatorIds
                updateIfNotInProgress()
            }
        case let .failure(error):
            logger.error("Unexpected subscription error: \(error)")

            clearSubscriptionAndRequest()
        }
    }
}

extension MythosStakingIdentitiesSyncService: MythosStakingIdentitiesSyncServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<[AccountId: AccountIdentity]>.StateChangeClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.addObserver(
            with: observer,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue,
            closure: closure
        )
    }

    func remove(observer: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.removeObserver(by: observer)
    }
}
