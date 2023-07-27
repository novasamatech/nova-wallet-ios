import Foundation
import SubstrateSdk
import RobinHood

final class EraNominationPoolsService: BaseSyncService {
    private struct PendingRequest {
        let resultClosure: (NominationPools.ActivePools) -> Void
        let queue: DispatchQueue?
    }

    private var snapshot: NominationPools.ActivePools?
    private var pendingRequests: [PendingRequest] = []

    let chainAsset: ChainAsset
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let eventCenter: EventCenterProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let operationFactory: NominationPoolsOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol

    private var lastPoolId: NominationPools.PoolId?
    private var activePoolCancellable: CancellableCall?
    private var lastPoolIdProvider: AnyDataProvider<DecodedPoolId>?

    init(
        chainAsset: ChainAsset,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.novawallet.activepools", qos: .userInitiated),
        eventCenter: EventCenterProtocol = EventCenter.shared,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chainAsset = chainAsset
        self.runtimeCodingService = runtimeCodingService
        self.operationFactory = operationFactory
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.eraValidatorService = eraValidatorService
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.eventCenter = eventCenter

        super.init(logger: logger)
    }

    override func performSyncUp() {
        updateActiveValidatorSubscription()

        lastPoolIdProvider = subscribeLastPoolId(for: chainAsset.chain.chainId)

        if lastPoolIdProvider == nil {
            logger?.error("Can't subscribe last pool id")

            completeImmediate(CommonError.dataCorruption)
        }
    }

    override func stopSyncUp() {
        clearUpdateOperation()
    }

    override func deactivate() {
        eventCenter.remove(observer: self)
        clearSubscriptions()
    }

    private func clearSubscriptions() {
        lastPoolIdProvider = nil
    }

    private func clearUpdateOperation() {
        activePoolCancellable?.cancel()
        activePoolCancellable = nil
    }

    private func updateActiveValidatorSubscription() {
        eventCenter.remove(observer: self)
        eventCenter.add(observer: self, dispatchIn: workingQueue)
    }

    private func updateActivePools() {
        guard let lastPoolId = lastPoolId else {
            completeImmediate(CommonError.dataCorruption)
            return
        }

        clearUpdateOperation()

        let wrapper = operationFactory.createActivePoolsInfoWrapper(
            for: eraValidatorService,
            lastPoolId: lastPoolId,
            runtimeService: runtimeCodingService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            self?.workingQueue.async {
                self?.mutex.lock()

                defer {
                    self?.mutex.unlock()
                }

                guard self?.activePoolCancellable === wrapper else {
                    return
                }

                self?.activePoolCancellable = nil

                do {
                    let activePools = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.handle(newActivePools: activePools)
                    self?.complete(nil)
                    self?.notifyAll()
                } catch {
                    self?.logger?.error("Can't fetch active pools: \(error)")
                    self?.completeImmediate(error)
                }
            }
        }

        activePoolCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func handle(newActivePools: NominationPools.ActivePools) {
        logger?.debug("New active pools \(newActivePools)")

        snapshot = newActivePools

        if !pendingRequests.isEmpty {
            let requests = pendingRequests
            pendingRequests = []

            requests.forEach { deliver(snapshot: newActivePools, to: $0) }

            logger?.debug("Fulfilled pendings")
        }
    }

    private func deliver(snapshot: NominationPools.ActivePools, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(snapshot)
        }
    }

    private func notifyAll() {
        eventCenter.notify(with: EraNominationPoolsChanged())
    }

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (NominationPools.ActivePools) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }
}

extension EraNominationPoolsService: EraNominationPoolsServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<NominationPools.ActivePools> {
        ClosureOperation {
            var fetchedInfo: NominationPools.ActivePools?

            let semaphore = DispatchSemaphore(value: 0)

            self.mutex.lock()

            self.fetchInfoFactory(runCompletionIn: nil) { [weak semaphore] info in
                fetchedInfo = info
                semaphore?.signal()
            }

            self.mutex.unlock()

            semaphore.wait()

            guard let info = fetchedInfo else {
                throw CommonError.dataCorruption
            }

            return info
        }
    }
}

extension EraNominationPoolsService: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleLastPoolId(result: Result<NominationPools.PoolId?, Error>, chainId _: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        markSyncingImmediate()

        switch result {
        case let .success(optLastPoolId):
            lastPoolId = optLastPoolId

            if let lastPoolId = optLastPoolId {
                updateActivePools()
            } else {
                logger?.warning("No pools registered yet")
                completeImmediate(nil)
            }
        case let .failure(error):
            logger?.error("Did receive error: \(error)")
        }
    }
}

extension EraNominationPoolsService: EventVisitorProtocol {
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        markSyncingImmediate()

        updateActivePools()
    }
}
