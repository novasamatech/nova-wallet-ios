import Foundation
import Operation_iOS
import SubstrateSdk

protocol BlockTimeEstimationServiceProtocol: ApplicationServiceProtocol {
    func createEstimatedBlockTimeOperation() -> BaseOperation<EstimatedBlockTime>
}

struct EstimatedBlockTime: Codable {
    let blockTime: BlockTime
    let seqSize: Int

    static func storageKey(for chainId: ChainModel.Id) -> String {
        chainId + "_block_time"
    }
}

struct BlockTimeSubscriptionModel: BatchStorageSubscriptionResult {
    let blockNumber: BlockNumber
    let timestamp: BlockTime
    let blockHash: Data?

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        blockNumber = try values[0].value.map(
            to: StringScaleMapper<BlockNumber>.self,
            with: context
        ).value

        timestamp = try values[1].value.map(
            to: StringScaleMapper<BlockTime>.self,
            with: context
        ).value

        blockHash = try blockHashJson.map(to: Data?.self, with: context)
    }
}

final class BlockTimeEstimationService {
    private struct Snapshot {
        let blockTime: TimeInterval
        let lastBlock: BlockNumber?
        let seqSize: Int
        let lastTime: BlockTime?

        var estimatedBlockTime: EstimatedBlockTime {
            EstimatedBlockTime(blockTime: BlockTime(blockTime.milliseconds), seqSize: seqSize)
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

    private var subscription: CallbackBatchStorageSubscription<BlockTimeSubscriptionModel>?

    private var pendingRequests: [UUID: PendingRequest] = [:]

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
        assigning requestId: UUID,
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (EstimatedBlockTime) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(estimatedBlockTime: snapshot.estimatedBlockTime, to: request)
        } else {
            pendingRequests[requestId] = request
        }
    }

    private func cancel(for requestId: UUID) {
        pendingRequests[requestId] = nil
    }

    private func deliver(estimatedBlockTime: EstimatedBlockTime) {
        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = [:]

        for request in requests.values {
            deliver(estimatedBlockTime: estimatedBlockTime, to: request)
        }
    }

    private func deliver(estimatedBlockTime: EstimatedBlockTime, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(estimatedBlockTime)
        }
    }

    private func readStartBlock(for chainId: ChainModel.Id) {
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
                self?.logger.error("\(chainId) Unexpected error: \(error)")
            }
        }

        mapOperation.addDependency(localQueryOperation)

        operationQueue.addOperations([localQueryOperation, mapOperation], waitUntilFinished: false)
    }

    private func setupInitialSnapshot(for estimatedBlockTime: EstimatedBlockTime) {
        syncQueue.async { [weak self] in
            let snapshot = Snapshot(
                blockTime: estimatedBlockTime.blockTime.timeInterval,
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
        guard isActive else {
            return
        }

        let storagePaths: [StorageCodingPath] = [SystemPallet.blockNumberPath, .timestampNow]
        let optRequests: [UnkeyedSubscriptionRequest]? = try? storagePaths.map { path in
            let localKey = try localKeyFactory.createFromStoragePath(path, chainId: chainId)
            return UnkeyedSubscriptionRequest(storagePath: path, localKey: localKey)
        }

        guard let requests = optRequests else {
            return
        }

        subscription = CallbackBatchStorageSubscription(
            requests: requests.map { BatchStorageSubscriptionRequest(innerRequest: $0, mappingKey: nil) },
            connection: connection,
            runtimeService: runtimeService,
            repository: repository,
            operationQueue: operationQueue,
            callbackQueue: syncQueue
        ) { [weak self] (result: Result<BlockTimeSubscriptionModel, Error>) in
            self?.processResult(result)
        }

        subscription?.subscribe()
    }

    private func processResult(_ result: Result<BlockTimeSubscriptionModel, Error>) {
        switch result {
        case let .success(model):
            processBlockNumber(model)
        case let .failure(error):
            logger.error("\(chainId) Unexpected error: \(error)")
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

    private func processBlockNumber(_ model: BlockTimeSubscriptionModel) {
        guard let prevSnapshot = snapshot else {
            return
        }

        // sync block number first
        guard
            let lastBlock = prevSnapshot.lastBlock,
            model.blockNumber == lastBlock + 1 else {
            let lastTime = model.blockNumber == prevSnapshot.lastBlock ? prevSnapshot.lastTime : nil
            snapshot = Snapshot(
                blockTime: prevSnapshot.blockTime,
                lastBlock: model.blockNumber,
                seqSize: prevSnapshot.seqSize,
                lastTime: lastTime
            )
            return
        }

        let currentTime = model.timestamp

        // then sync time diff
        if
            let prevTime = prevSnapshot.lastTime,
            currentTime > prevTime {
            let newBlockTimeElement = (currentTime - prevTime).timeInterval

            logger.debug("(\(chainId) Block time: \(newBlockTimeElement)")

            let blockTime = prevSnapshot.blockTime
            let seqSize = prevSnapshot.seqSize
            let newBlockTime = (blockTime * TimeInterval(seqSize) + newBlockTimeElement) / TimeInterval(seqSize + 1)

            logger.debug("\(chainId) Cumulative block time: \(newBlockTime)")

            let newSnapshot = Snapshot(
                blockTime: newBlockTime,
                lastBlock: model.blockNumber,
                seqSize: seqSize + 1,
                lastTime: currentTime
            )

            snapshot = newSnapshot

            let estimatedBlockTime = newSnapshot.estimatedBlockTime
            save(blockTime: estimatedBlockTime)

            deliver(estimatedBlockTime: estimatedBlockTime)
        } else {
            snapshot = Snapshot(
                blockTime: prevSnapshot.blockTime,
                lastBlock: model.blockNumber,
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

            self.readStartBlock(for: self.chainId)

            self.logger.debug("(\(self.chainId) block time service setup")
        }
    }

    func throttle() {
        syncQueue.async {
            guard self.isActive else {
                return
            }

            self.isActive = false

            self.subscription?.unsubscribe()
            self.subscription = nil

            self.logger.debug("(\(self.chainId) block time service throttled")
        }
    }

    func createEstimatedBlockTimeOperation() -> BaseOperation<EstimatedBlockTime> {
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
