import Foundation
import RobinHood
import SubstrateSdk

protocol RuntimeProviderProtocol: AnyObject, RuntimeCodingServiceProtocol {
    var chainId: ChainModel.Id { get }

    func setup()
    func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage)
    func cleanup()
}

enum RuntimeProviderError: Error {
    case providerUnavailable
}

final class RuntimeProvider {
    struct PendingRequest {
        let resultClosure: (RuntimeCoderFactoryProtocol?) -> Void
        let queue: DispatchQueue?
    }

    let chainId: ChainModel.Id
    private(set) var typesUsage: ChainModel.TypesUsage

    let snapshotOperationFactory: RuntimeSnapshotFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    private(set) var snapshot: RuntimeSnapshot?
    private(set) var pendingRequests: [UUID: PendingRequest] = [:]
    private(set) var currentWrapper: CompoundOperationWrapper<RuntimeSnapshot?>?
    private var mutex = NSLock()

    init(
        chainModel: ChainModel,
        snapshotOperationFactory: RuntimeSnapshotFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        chainId = chainModel.chainId
        typesUsage = chainModel.typesUsage
        self.snapshotOperationFactory = snapshotOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger

        eventCenter.add(observer: self, dispatchIn: DispatchQueue.global())
    }

    private func buildSnapshot(with typesUsage: ChainModel.TypesUsage) {
        let wrapper = snapshotOperationFactory.createRuntimeSnapshotWrapper(for: typesUsage)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.targetOperation.result)
            }
        }

        currentWrapper = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func handleCompletion(result: Result<RuntimeSnapshot?, Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case let .success(snapshot):
            currentWrapper = nil

            if let snapshot = snapshot {
                self.snapshot = snapshot

                logger?.debug("Did complete snapshot for: \(chainId)")
                logger?.debug("Will notify waiters: \(pendingRequests.count)")

                resolveRequests()

                let event = RuntimeCoderCreated(chainId: chainId)
                eventCenter.notify(with: event)
            }
        case let .failure(error):
            currentWrapper = nil

            logger?.debug("Failed to build snapshot for \(chainId): \(error)")

            let event = RuntimeCoderCreationFailed(chainId: chainId, error: error)
            eventCenter.notify(with: event)
        case .none:
            break
        }
    }

    private func cancelRequest(for requestId: UUID) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let maybePendingRequest = pendingRequests[requestId]
        pendingRequests[requestId] = nil

        if let pendingRequest = maybePendingRequest {
            deliver(snapshot: nil, to: pendingRequest)
        }
    }

    private func resolveRequests() {
        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = [:]

        requests.forEach { deliver(snapshot: snapshot, to: $0.value) }
    }

    private func deliver(snapshot: RuntimeSnapshot?, to request: PendingRequest) {
        let coderFactory = snapshot.map {
            RuntimeCoderFactory(
                catalog: $0.typeRegistryCatalog,
                specVersion: $0.specVersion,
                txVersion: $0.txVersion,
                metadata: $0.metadata
            )
        }

        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(coderFactory)
        }
    }

    private func fetchCoderFactory(
        assigning requestId: UUID,
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RuntimeCoderFactoryProtocol?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests[requestId] = request
        }
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let requestId = UUID()

        return AsyncClosureOperation(cancelationClosure: { [weak self] in
            self?.cancelRequest(for: requestId)
        }) { [weak self] responseClosure in
            if let strongSelf = self {
                strongSelf.fetchCoderFactory(assigning: requestId, runCompletionIn: nil) { maybeFactory in
                    if let factory = maybeFactory {
                        responseClosure(.success(factory))
                    } else {
                        responseClosure(nil)
                    }
                }
            } else {
                responseClosure(.failure(RuntimeProviderError.providerUnavailable))
            }
        }
    }
}

extension RuntimeProvider: RuntimeProviderProtocol {
    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentWrapper == nil else {
            return
        }

        buildSnapshot(with: typesUsage)
    }

    func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard typesUsage != newTypeUsage else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        typesUsage = newTypeUsage

        buildSnapshot(with: newTypeUsage)
    }

    func cleanup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        snapshot = nil

        currentWrapper?.cancel()
        currentWrapper = nil

        resolveRequests()
    }
}

extension RuntimeProvider: EventVisitorProtocol {
    func processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted) {
        guard event.chainId == chainId else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard snapshot?.localChainHash != event.fileHash else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        logger?.debug("Will start building snapshot after chain types update for \(chainId)")

        buildSnapshot(with: typesUsage)
    }

    func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted) {
        guard event.chainId == chainId else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        logger?.debug("Will start building snapshot after metadata update for \(chainId)")

        buildSnapshot(with: typesUsage)
    }

    func processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted) {
        guard typesUsage != .onlyOwn else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard snapshot?.localCommonHash != event.fileHash else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        logger?.debug("Will start building snapshot after common types update for \(chainId)")

        buildSnapshot(with: typesUsage)
    }
}
