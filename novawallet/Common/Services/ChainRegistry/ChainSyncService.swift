import Foundation
import Operation_iOS
import SubstrateSdk

protocol ChainSyncServiceProtocol {
    func syncUp()
    func updateLocal(chain: ChainModel)
}

final class ChainSyncService {
    struct SyncChanges {
        let newOrUpdatedItems: [ChainModel]
        let removedItems: [ChainModel]
    }

    let url: URL
    let evmAssetsURL: URL
    let chainConverter: ChainModelConversionProtocol
    let repository: AnyDataProviderRepository<ChainModel>
    let dataFetchFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    private(set) var retryAttempt: Int = 0
    private(set) var isSyncing: Bool = false
    private let mutex = NSLock()

    private lazy var scheduler: Scheduler = {
        let scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
        return scheduler
    }()

    init(
        url: URL,
        evmAssetsURL: URL,
        chainConverter: ChainModelConversionProtocol,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil
    ) {
        self.url = url
        self.dataFetchFactory = dataFetchFactory
        self.chainConverter = chainConverter
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.retryStrategy = retryStrategy
        self.logger = logger
        self.evmAssetsURL = evmAssetsURL
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            logger?.debug("Tried to sync up chains but already syncing")
            return
        }

        isSyncing = true
        retryAttempt += 1

        logger?.debug("Will start chain sync with attempt \(retryAttempt)")

        let event = ChainSyncDidStart()
        eventCenter.notify(with: event)

        executeSync(using: chainConverter)
    }

    private func executeSync(using chainConverter: ChainModelConversionProtocol) {
        let remoteFetchOperation = dataFetchFactory.fetchData(from: url)
        let evmRemoteFetchOperation = dataFetchFactory.fetchData(from: evmAssetsURL)

        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let processingOperation: BaseOperation<SyncChanges> = ClosureOperation {
            let decoder = JSONDecoder()
            let remoteData = try remoteFetchOperation.extractNoCancellableResultData()
            let remoteItems = try decoder.decode(RemoteChainsModel.self, from: remoteData)
            let evmRemoteData = try evmRemoteFetchOperation.extractNoCancellableResultData()
            let evmRemoteItems = try decoder.decode([RemoteEvmToken].self, from: evmRemoteData)
            let remoteEvmTokens = evmRemoteItems.chainAssets()

            let remoteMapping = remoteItems.chains.reduce(
                into: [ChainModel.Id: RemoteChainModel]()
            ) { mapping, item in
                mapping[item.chainId] = item
            }

            let localChains = try localFetchOperation.extractNoCancellableResultData()
            let localMapping = localChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }

            let newOrUpdated: [ChainModel] = remoteItems.chains.enumerated().compactMap { index, remoteItem in
                let localItem = localMapping[remoteItem.chainId]

                if let localItem, localItem.source == .user {
                    return nil
                }

                return chainConverter.update(
                    localModel: localItem,
                    remoteModel: remoteItem,
                    additionalAssets: remoteEvmTokens[remoteItem.chainId] ?? [],
                    order: Int64(index)
                )
            }

            let removed: [ChainModel] = localChains.compactMap { localItem in
                guard localItem.source == .remote else {
                    return nil
                }

                return remoteMapping[localItem.chainId] == nil ? localItem : nil
            }

            return SyncChanges(newOrUpdatedItems: newOrUpdated, removedItems: removed)
        }

        processingOperation.addDependency(remoteFetchOperation)
        processingOperation.addDependency(evmRemoteFetchOperation)
        processingOperation.addDependency(localFetchOperation)

        let localSaveOperation = repository.saveOperation({
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.newOrUpdatedItems
        }, {
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.removedItems.map(\.identifier)
        })

        localSaveOperation.addDependency(processingOperation)

        let mapOperation: BaseOperation<SyncChanges> = ClosureOperation {
            _ = try localSaveOperation.extractNoCancellableResultData()

            return try processingOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(localSaveOperation)

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.complete(result: mapOperation.result)
            }
        }

        operationQueue.addOperations([
            remoteFetchOperation,
            evmRemoteFetchOperation,
            localFetchOperation,
            processingOperation,
            localSaveOperation,
            mapOperation
        ], waitUntilFinished: false)
    }

    private func complete(result: Result<SyncChanges, Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false

        switch result {
        case let .success(changes):
            logger?.debug(
                """
                Sync completed: \(changes.newOrUpdatedItems) (new or updated),
                \(changes.removedItems) (removed)
                """
            )

            retryAttempt = 0

            let event = ChainSyncDidComplete(
                newOrUpdatedChains: changes.newOrUpdatedItems,
                removedChains: changes.removedItems
            )

            eventCenter.notify(with: event)
        case let .failure(error):
            logger?.error("Sync failed with error: \(error)")

            let event = ChainSyncDidFail(error: error)
            eventCenter.notify(with: event)

            retry()
        case .none:
            logger?.error("Sync failed with no result")

            let event = ChainSyncDidFail(error: BaseOperationError.unexpectedDependentResult)
            eventCenter.notify(with: event)

            retry()
        }
    }

    private func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            logger?.debug("Scheduling chain sync retry after \(nextDelay)")

            scheduler.notifyAfter(nextDelay)
        }
    }
}

extension ChainSyncService: ChainSyncServiceProtocol {
    func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        performSyncUpIfNeeded()
    }

    func updateLocal(chain: ChainModel) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let operation = repository.saveOperation({ [chain] }, { [] })

        operationQueue.addOperation(operation)
    }
}

extension ChainSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}
