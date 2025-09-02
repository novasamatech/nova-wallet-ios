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
    let syncService: MythosStakingStakeSyncService
    let operationFactory: MythosStakingClaimRewardsFactoryProtocol
    let operationQueue: OperationQueue

    private let syncQueue: DispatchQueue
    private let callStore = CancellableCallStore()

    private var stateObservable: Observable<MythosStakingClaimableRewards?> = .init(state: nil)

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        syncService: MythosStakingStakeSyncService,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.syncService = syncService
        self.operationQueue = operationQueue

        operationFactory = MythosStakingClaimRewardsFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        syncQueue = DispatchQueue(label: "io.novawallet.mythos.rewards.sync.\(UUID().uuidString)")
    }

    deinit {
        callStore.cancel()
    }

    override func performSyncUp() {
        clearSubscriptionAndRequest()

        syncService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: syncQueue
        ) { [weak self] _, newState in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            guard let newState else {
                return
            }

            self?.logger.debug("New change: \(newState)")

            self?.updateState(for: newState.lastChange.blockHash)
        }
    }

    override func stopSyncUp() {
        clearSubscriptionAndRequest()
    }
}

private extension MythosStakingClaimableRewardsService {
    func updateState(for blockHash: Data?) {
        callStore.cancel()

        let shouldClaimWrapper = operationFactory.shouldClaimRewardsWrapper(
            for: chainId,
            accountId: accountId,
            at: blockHash
        )

        let totalRewardsWrapper = operationFactory.totalRewardsWrapper(
            for: chainId,
            accountId: accountId,
            at: blockHash
        )

        let mappingOperation = ClosureOperation<MythosStakingClaimableRewards> {
            let shouldClaim = try shouldClaimWrapper.targetOperation.extractNoCancellableResultData()
            let totalRewards = try totalRewardsWrapper.targetOperation.extractNoCancellableResultData()

            return MythosStakingClaimableRewards(total: totalRewards, shouldClaim: shouldClaim)
        }

        mappingOperation.addDependency(totalRewardsWrapper.targetOperation)
        mappingOperation.addDependency(shouldClaimWrapper.targetOperation)

        logger.debug("Will start query at: \(String(describing: blockHash?.toHexWithPrefix()))")

        let resultWrapper = totalRewardsWrapper
            .insertingHead(operations: shouldClaimWrapper.allOperations)
            .insertingTail(operation: mappingOperation)

        executeCancellable(
            wrapper: resultWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: syncQueue,
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

    func clearSubscriptionAndRequest() {
        syncService.remove(observer: self)

        callStore.cancel()
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
