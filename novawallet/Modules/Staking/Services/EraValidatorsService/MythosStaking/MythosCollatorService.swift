import Foundation
import Operation_iOS
import SubstrateSdk

final class MythosCollatorService {
    static let queueLabelPrefix = "com.novawallet.mythos.collators"

    private struct PendingRequest {
        let resultClosure: (MythosSessionCollators) -> Void
        let queue: DispatchQueue?
    }

    let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    let chainId: ChainModel.Id
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let operationFactory: MythosCollatorOperationFactoryProtocol
    let logger: LoggerProtocol

    private var snapshot: MythosSessionCollators?
    private var validatorsSubscription: CallbackStorageSubscription<[BytesCodable]>?
    private var pendingRequests: [UUID: PendingRequest] = [:]
    private var isActive: Bool = false
    private var infoCancellableStore = CancellableCallStore()

    init(
        chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.logger = logger

        operationFactory = MythosCollatorOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            timeout: JSONRPCTimeout.hour
        )
    }

    func didReceiveSnapshot(_ snapshot: MythosSessionCollators) {
        logger.debug("Attempt fulfill pendings \(pendingRequests.count)")

        self.snapshot = snapshot

        if !pendingRequests.isEmpty {
            let requests = pendingRequests
            pendingRequests = [:]

            requests.values.forEach { deliver(snapshot: snapshot, to: $0) }

            logger.debug("Fulfilled pendings")
        }

        let event = EraStakersInfoChanged(chainId: chainId)
        eventCenter.notify(with: event)
    }
}

private extension MythosCollatorService {
    private func fetchInfoFactory(
        assigning requestId: UUID,
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (MythosSessionCollators) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests[requestId] = request
        }
    }

    private func cancel(for requestId: UUID) {
        pendingRequests[requestId] = nil
    }

    private func deliver(snapshot: MythosSessionCollators, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(snapshot)
        }
    }

    private func subscribe() {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            validatorsSubscription = CallbackStorageSubscription(
                request: UnkeyedSubscriptionRequest(
                    storagePath: SessionPallet.validatorsPath,
                    localKey: ""
                ),
                connection: connection,
                runtimeService: runtimeProvider,
                repository: nil,
                operationQueue: operationQueue,
                callbackQueue: syncQueue
            ) { [weak self] result in
                switch result {
                case let .success(wrappedCollators):
                    guard let wrappedCollators else {
                        return
                    }

                    let collators = wrappedCollators.map(\.wrappedValue)
                    self?.updateIfNeeded(for: collators)
                case let .failure(error):
                    self?.logger.error("Unexpected subscription error: \(error)")
                }
            }
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }

    private func unsubscribe() {
        validatorsSubscription?.unsubscribe()
        validatorsSubscription = nil
    }

    func updateIfNeeded(for collatorIds: [AccountId]) {
        infoCancellableStore.cancel()

        let infoWrapper = operationFactory.createFetchCollatorsInfo(
            for: chainId,
            collatorIdsClosure: { collatorIds }
        )

        let invulnerablesWrapper = operationFactory.createInvulnerableCollators(for: chainId)

        let mappingOperation = ClosureOperation<MythosSessionCollators> {
            let accountMapping = try infoWrapper.targetOperation.extractNoCancellableResultData()
            let invulnerables = try invulnerablesWrapper.targetOperation.extractNoCancellableResultData()

            return collatorIds.map { collatorId in
                MythosSessionCollator(
                    accountId: collatorId,
                    info: accountMapping[collatorId],
                    invulnerable: invulnerables.contains(collatorId)
                )
            }
        }

        mappingOperation.addDependency(infoWrapper.targetOperation)
        mappingOperation.addDependency(invulnerablesWrapper.targetOperation)

        let totalWrapper = invulnerablesWrapper
            .insertingHead(operations: infoWrapper.allOperations)
            .insertingTail(operation: mappingOperation)

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: infoCancellableStore,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            switch result {
            case let .success(sessionCollators):
                self?.didReceiveSnapshot(sessionCollators)
            case let .failure(error):
                // we don't need to handle error here since the branch is called only in case parsing fail
                self?.logger.error("Collators info fetch error: \(error)")
            }
        }
    }
}

extension MythosCollatorService: MythosCollatorServiceProtocol {
    func setup() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = true

            self.subscribe()
        }
    }

    func throttle() {
        syncQueue.async {
            guard self.isActive else {
                return
            }

            self.isActive = false

            self.unsubscribe()
        }
    }

    func fetchInfoOperation() -> BaseOperation<MythosSessionCollators> {
        let requestId = UUID()

        return AsyncClosureOperation(
            operationClosure: { closure in
                self.syncQueue.async {
                    self.fetchInfoFactory(assigning: requestId, runCompletionIn: nil) { info in
                        closure(.success(info))
                    }
                }
            },
            cancelationClosure: {
                self.syncQueue.async {
                    self.cancel(for: requestId)
                }
            }
        )
    }
}
