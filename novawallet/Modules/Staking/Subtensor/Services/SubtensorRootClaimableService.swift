import Foundation
import BigInt
import Operation_iOS

struct SubtensorRootClaimable: Equatable {
    let owed: Balance
    let positions: [SubtensorStakingPallet.RootBasketPosition]

    func payout(for hotkey: AccountId) -> Balance {
        positions.first { $0.hotkey == hotkey }?.payout ?? 0
    }
}

protocol SubtensorRootClaimableServiceProtocol: ApplicationServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<SubtensorRootClaimable?>.StateChangeClosure
    )

    func remove(observer: AnyObject)
}

final class SubtensorRootClaimableService: BaseSyncService {
    let coldkey: AccountId
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    private let syncQueue: DispatchQueue
    private let callStore = CancellableCallStore()

    private var stateObservable: Observable<SubtensorRootClaimable?> = .init(state: nil)

    init(
        coldkey: AccountId,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol,
        operationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.coldkey = coldkey
        self.positionsSyncService = positionsSyncService
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue

        syncQueue = DispatchQueue(label: "io.novawallet.subtensor.claimable.sync.\(UUID().uuidString)")
    }

    deinit {
        callStore.cancel()
    }

    override func performSyncUp() {
        clearSubscriptionAndRequest()

        positionsSyncService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: syncQueue
        ) { [weak self] _, newState in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            guard newState != nil else {
                return
            }

            self?.updateClaimable()
        }
    }

    override func stopSyncUp() {
        clearSubscriptionAndRequest()
    }
}

private extension SubtensorRootClaimableService {
    func createPinnedClaimableWrapper(
        at blockHash: BlockHash
    ) -> CompoundOperationWrapper<SubtensorRootClaimable> {
        let owedWrapper = operationFactory.createRootBasketOwedWrapper(
            for: coldkey,
            blockHash: blockHash
        )

        let positionsWrapper = operationFactory.createRootBasketPositionsWrapper(
            for: coldkey,
            blockHash: blockHash
        )

        let mergeOperation = ClosureOperation<SubtensorRootClaimable> {
            let owed = try owedWrapper.targetOperation.extractNoCancellableResultData()
            let positions = try positionsWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorRootClaimable(owed: owed, positions: positions)
        }

        mergeOperation.addDependency(owedWrapper.targetOperation)
        mergeOperation.addDependency(positionsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: owedWrapper.allOperations + positionsWrapper.allOperations
        )
    }

    func updateClaimable() {
        callStore.cancel()

        let blockHashWrapper = operationFactory.createBestBlockHashWrapper()

        let claimableWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let blockHash = try blockHashWrapper.targetOperation.extractNoCancellableResultData()

            return createPinnedClaimableWrapper(at: blockHash)
        }

        claimableWrapper.addDependency(wrapper: blockHashWrapper)

        let resultWrapper = claimableWrapper.insertingHead(operations: blockHashWrapper.allOperations)

        executeCancellable(
            wrapper: resultWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: syncQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(claimable):
                self?.stateObservable.state = claimable

                self?.completeImmediate(nil)
            case let .failure(error):
                self?.logger.error("Claimable fetch error: \(error)")

                self?.completeImmediate(error)
            }
        }
    }

    func clearSubscriptionAndRequest() {
        positionsSyncService.remove(observer: self)

        callStore.cancel()
    }
}

extension SubtensorRootClaimableService: SubtensorRootClaimableServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<SubtensorRootClaimable?>.StateChangeClosure
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
