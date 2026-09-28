import Foundation
import BigInt
import Operation_iOS

struct SubtensorRootClaimable: Equatable {
    let previews: [SubtensorRootClaimPreview]

    var totalRedeemable: Balance {
        previews.reduce(Balance.zero) { $0 + $1.redeemable }
    }

    func redeemable(for hotkey: AccountId) -> Balance {
        previews.first { $0.hotkey == hotkey }?.redeemable ?? 0
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

    func add(
        failureObserver: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Bool>.StateChangeClosure
    )

    func remove(failureObserver: AnyObject)
}

final class SubtensorRootClaimableService: BaseSyncService {
    let coldkey: AccountId
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    private let syncQueue: DispatchQueue
    private let callStore = CancellableCallStore()

    private var stateObservable: Observable<SubtensorRootClaimable?> = .init(state: nil)
    private var failureObservable: Observable<Bool> = .init(state: false)

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

            guard newState != nil, self?.isActive == true else {
                return
            }

            self?.updateClaimable()
        }
    }

    override func stopSyncUp() {
        clearSubscriptionAndRequest()
    }

    override func deactivate() {
        clearSubscriptionAndRequest()
    }
}

private extension SubtensorRootClaimableService {
    func createPinnedClaimableWrapper(
        at blockHash: BlockHash
    ) -> CompoundOperationWrapper<SubtensorRootClaimable> {
        let previewsWrapper = operationFactory.createRootClaimPreviewsWrapper(
            coldkey: coldkey,
            blockHash: blockHash
        )

        let mappingOperation = ClosureOperation<SubtensorRootClaimable> {
            let previews = try previewsWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorRootClaimable(
                previews: previews.map { preview in
                    SubtensorRootClaimPreview(
                        hotkey: preview.hotkey,
                        accrued: preview.accruedTao,
                        redeemable: preview.redeemableTao,
                        forfeitedEstimate: preview.forfeitedTaoEst
                    )
                }
            )
        }

        mappingOperation.addDependency(previewsWrapper.targetOperation)

        return previewsWrapper.insertingTail(operation: mappingOperation)
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
                self?.failureObservable.state = false

                self?.stateObservable.state = claimable

                self?.completeImmediate(nil)
            case let .failure(error):
                self?.logger.error("Claimable fetch error: \(error)")

                self?.failureObservable.state = true

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

    func add(
        failureObserver: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<Bool>.StateChangeClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        failureObservable.addObserver(
            with: failureObserver,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue,
            closure: closure
        )
    }

    func remove(failureObserver: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        failureObservable.removeObserver(by: failureObserver)
    }
}
