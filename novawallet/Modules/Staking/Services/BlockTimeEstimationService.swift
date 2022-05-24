import Foundation
import RobinHood
import SubstrateSdk

protocol BlockTimeEstimationServiceProtocol: ApplicationServiceProtocol {
    func createEstimatedBlockTimeOperation() -> BaseOperation<EstimatedBlockTime>
}

struct EstimatedBlockTime: Codable {
    let blockTime: Moment
    let seqSize: Int

    static func storageKey(for chainId: ChainModel.Id) -> String {
        chainId + "_block_time"
    }
}

final class BlockTimeEstimationService {
    private struct Snapshot {
        let blockTime: Moment
        let lastBlock: BlockNumber?
        let seqSize: Int
        let lastTime: TimeInterval?

        var estimatedBlockTime: EstimatedBlockTime {
            EstimatedBlockTime(blockTime: blockTime, seqSize: seqSize)
        }

        static var empty: Snapshot {
            Snapshot(blockTime: 0, lastBlock: nil, seqSize: 0, lastTime: nil)
        }
    }

    private struct PendingRequest {
        let resultClosure: (EstimatedBlockTime) -> Void
        let queue: DispatchQueue?
    }

    let chainId: ChainModel.Id
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let repository: AnyDataProviderRepository<ChainStorageItem>
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol
    let operationQueue: OperationQueue

    private let syncQueue = DispatchQueue(
        label: "com.novawallet.block.time.\(UUID().uuidString)",
        qos: .userInitiated
    )

    private var snapshot: Snapshot?

    private var subscription: CallbackStorageSubscription<StringScaleMapper<Moment>>?

    private var pendingRequests: [PendingRequest] = []

    private(set) var isActive: Bool = false

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        chainId: ChainModel.Id,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        repository: AnyDataProviderRepository<ChainStorageItem>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.connection = connection
        self.runtimeService = runtimeService
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (EstimatedBlockTime) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(estimatedBlockTime: snapshot.estimatedBlockTime, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(estimatedBlockTime: EstimatedBlockTime) {
        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        for request in requests {
            deliver(estimatedBlockTime: estimatedBlockTime, to: request)
        }
    }

    private func deliver(estimatedBlockTime: EstimatedBlockTime, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(estimatedBlockTime)
        }
    }

    private func readStartBlock() {
        let modelId = EstimatedBlockTime.storageKey(for: chainId)
        let localQueryOperation = repository.fetchOperation(by: modelId, options: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<EstimatedBlockTime> {
            if
                let object = try? localQueryOperation.extractNoCancellableResultData(),
                let blockTime = try? JSONDecoder().decode(EstimatedBlockTime.self, from: object.data) {
                return blockTime
            } else {
                return EstimatedBlockTime(blockTime: 0, seqSize: 0)
            }
        }

        mapOperation.completionBlock = { [weak self] in
            do {
                let blockTime = try mapOperation.extractNoCancellableResultData()
                self?.setupInitialSnapshot(for: blockTime)
            } catch {
                self?.logger.error("Unexpected error: \(error)")
            }
        }

        mapOperation.addDependency(localQueryOperation)

        operationQueue.addOperations([localQueryOperation, mapOperation], waitUntilFinished: false)
    }

    private func setupInitialSnapshot(for estimatedBlockTime: EstimatedBlockTime) {
        syncQueue.async { [weak self] in
            let snapshot = Snapshot(
                blockTime: estimatedBlockTime.blockTime,
                lastBlock: nil,
                seqSize: estimatedBlockTime.seqSize,
                lastTime: nil
            )

            self?.snapshot = snapshot

            self?.deliver(estimatedBlockTime: snapshot.estimatedBlockTime)
            self?.subscribeBlockNumber()
        }
    }

    private func subscribeBlockNumber() {
        guard
            isActive,
            let localKey = try? localKeyFactory.createFromStoragePath(.blockNumber, chainId: chainId) else {
            return
        }

        subscription = CallbackStorageSubscription(
            request: UnkeyedSubscriptionRequest(storagePath: .blockNumber, localKey: localKey),
            storagePath: .blockNumber,
            connection: connection,
            runtimeService: runtimeService,
            repository: repository,
            operationQueue: operationQueue,
            callbackQueue: syncQueue
        ) { [weak self] (result: Result<StringScaleMapper<Moment>?, Error>) in
            self?.processResult(result)
        }
    }

    private func processResult(_ result: Result<StringScaleMapper<Moment>?, Error>) {
        switch result {
        case let .success(optBlockNumber):
            processBlockNumber(optBlockNumber?.value)
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
        }
    }

    private func notifyAfterSave() {
        eventCenter.notify(with: BlockTimeChanged(chainId: chainId))
    }

    private func save(blockTime: EstimatedBlockTime) {
        let localKey = EstimatedBlockTime.storageKey(for: chainId)

        let saveOperation = repository.saveOperation({
            let data = try JSONEncoder().encode(blockTime)
            let item = ChainStorageItem(identifier: localKey, data: data)
            return [item]
        }, { [] })

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.notifyAfterSave()
            }
        }

        operationQueue.addOperation(saveOperation)
    }

    private func processBlockNumber(_ blockNumber: Moment?) {
        guard let blockNumber = blockNumber, let prevSnapshot = snapshot else {
            return
        }

        // sync block number first
        guard
            let lastBlock = prevSnapshot.lastBlock,
            blockNumber == lastBlock + 1 else {
            let lastTime = blockNumber == prevSnapshot.lastBlock ? prevSnapshot.lastTime : nil
            snapshot = Snapshot(
                blockTime: prevSnapshot.blockTime,
                lastBlock: blockNumber,
                seqSize: prevSnapshot.seqSize,
                lastTime: lastTime
            )
            return
        }

        let currentTime = Date().timeIntervalSince1970

        // then sync time diff
        if
            let prevTime = prevSnapshot.lastTime,
            currentTime > prevTime {
            let newBlockTimeElement = Moment((currentTime - prevTime).milliseconds)

            logger.debug("Block time: \(newBlockTimeElement)")

            let blockTime = prevSnapshot.blockTime
            let seqSize = prevSnapshot.seqSize
            let newBlockTime = (blockTime * Moment(seqSize) + newBlockTimeElement) / Moment(seqSize + 1)

            logger.debug("Cumulative block time: \(newBlockTime)")

            snapshot = Snapshot(
                blockTime: newBlockTime,
                lastBlock: blockNumber,
                seqSize: seqSize + 1,
                lastTime: currentTime
            )

            let estimatedBlockTime = EstimatedBlockTime(blockTime: newBlockTime, seqSize: seqSize + 1)
            save(blockTime: estimatedBlockTime)

            deliver(estimatedBlockTime: estimatedBlockTime)
        } else {
            snapshot = Snapshot(
                blockTime: prevSnapshot.blockTime,
                lastBlock: blockNumber,
                seqSize: prevSnapshot.seqSize,
                lastTime: currentTime
            )
        }
    }
}

extension BlockTimeEstimationService: BlockTimeEstimationServiceProtocol {
    func setup() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = true

            self.readStartBlock()
        }
    }

    func throttle() {
        syncQueue.async {
            guard self.isActive else {
                return
            }

            self.isActive = false

            self.subscription = nil
        }
    }

    func createEstimatedBlockTimeOperation() -> BaseOperation<EstimatedBlockTime> {
        ClosureOperation {
            var fetchedInfo: EstimatedBlockTime?

            let semaphore = DispatchSemaphore(value: 0)

            self.syncQueue.async {
                self.fetchInfoFactory(runCompletionIn: nil) { [weak semaphore] info in
                    fetchedInfo = info
                    semaphore?.signal()
                }
            }

            semaphore.wait()

            guard let info = fetchedInfo else {
                throw CommonError.dataCorruption
            }

            return info
        }
    }
}
