import Foundation
import SubstrateSdk
import Operation_iOS

protocol MythosStakingClaimableRewardsServiceProtocol: ApplicationServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<MythosStakingClaimableRewards?>.StateChangeClosure
    )

    func remove(observer: AnyObject)
}

final class MythosStakingClaimableRewardsService: BaseSyncService, AnyProviderAutoCleaning {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let operationFactory: MythosStakingClaimRewardsFactoryProtocol
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    private let callStore = CancellableCallStore()

    private var stateObservable: Observable<MythosStakingClaimableRewards?> = .init(state: nil)
    private var currentSessionProvider: AnyDataProvider<DecodedU32>?

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global()
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.operationQueue = operationQueue

        operationFactory = MythosStakingClaimRewardsFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        self.workQueue = workQueue
    }

    deinit {
        currentSessionProvider = nil
        callStore.cancel()
    }

    private func updateState() {
        let shouldClaimWrapper = operationFactory.shouldClaimRewardsWrapper(
            for: chainId,
            accountId: accountId
        )

        let totalRewardsWrapper = operationFactory.totalRewardsWrapper(
            for: chainId,
            accountId: accountId
        )

        let mappingOperation = ClosureOperation<MythosStakingClaimableRewards> {
            let shouldClaim = try shouldClaimWrapper.targetOperation.extractNoCancellableResultData()
            let totalRewards = try totalRewardsWrapper.targetOperation.extractNoCancellableResultData()

            return MythosStakingClaimableRewards(total: totalRewards, shouldClaim: shouldClaim)
        }

        mappingOperation.addDependency(totalRewardsWrapper.targetOperation)
        mappingOperation.addDependency(shouldClaimWrapper.targetOperation)

        let resultWrapper = totalRewardsWrapper
            .insertingHead(operations: shouldClaimWrapper.allOperations)
            .insertingTail(operation: mappingOperation)

        executeCancellable(
            wrapper: resultWrapper,
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

    private func clearSubscriptionAndRequest() {
        clear(dataProvider: &currentSessionProvider)

        callStore.cancel()
    }

    private func setupSubscription(for chainId: ChainModel.Id, accountId _: AccountId) {
        currentSessionProvider = subscribeToCurrentSession(
            for: chainId,
            callbackQueue: workQueue
        )
    }

    override func performSyncUp() {
        if currentSessionProvider == nil {
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

extension MythosStakingClaimableRewardsService: MythosStakingLocalStorageSubscriber,
    MythosStakingLocalStorageHandler {
    func handleCurrentSession(
        result: Result<SessionIndex?, Error>,
        chainId _: ChainModel.Id
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case let .success(session):
            logger.debug("Session: \(session)")

            markSyncingImmediate()
            updateState()
        case let .failure(error):
            logger.error("Unexpected subscription error: \(error)")

            clearSubscriptionAndRequest()
        }
    }
}

extension MythosStakingClaimableRewardsService: MythosStakingClaimableRewardsServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<MythosStakingClaimableRewards?>.StateChangeClosure
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
