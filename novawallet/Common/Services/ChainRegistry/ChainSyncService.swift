import Foundation
import RobinHood
import SubstrateSdk

protocol ChainSyncServiceProtocol {
    func syncUp()
}

final class ChainSyncService {
    struct SyncChanges {
        let newOrUpdatedItems: [ChainModel]
        let removedItems: [ChainModel]
    }

    let url: URL
    let evmAssetsURL: URL
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
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil
    ) {
        self.url = url
        self.dataFetchFactory = dataFetchFactory
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

        executeSync()
    }

    private func executeSync() {
        let remoteFetchOperation = dataFetchFactory.fetchData(from: url)
        let evmRemoteFetchOperation = dataFetchFactory.fetchData(from: evmAssetsURL)

        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let evmTokensProcessingOperation: BaseOperation<[ChainModel.Id: Set<AssetModel>]> = ClosureOperation {
            let remoteData = try evmRemoteFetchOperation.extractNoCancellableResultData()
            let remoteItems = try JSONDecoder().decode([RemoteEvmToken].self, from: remoteData)
            return Self.createAssets(evmTokens: remoteItems)
        }

        let processingOperation: BaseOperation<SyncChanges> = ClosureOperation {
            let remoteData = try remoteFetchOperation.extractNoCancellableResultData()
            let remoteItems = try JSONDecoder().decode([RemoteChainModel].self, from: remoteData)
            let remoteChains = remoteItems.enumerated().map { index, chain in
                ChainModel(remoteModel: chain, order: Int64(index))
            }
            let remoteEvmTokens = try evmTokensProcessingOperation.extractNoCancellableResultData()

            let remoteMapping = remoteChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                let chainModel: ChainModel
                if let evmTokens = remoteEvmTokens[item.chainId] {
                    chainModel = ChainModel(
                        chainId: item.chainId,
                        parentId: item.parentId,
                        name: item.name,
                        assets: item.assets.union(evmTokens),
                        nodes: item.nodes,
                        addressPrefix: item.addressPrefix,
                        types: item.types,
                        icon: item.icon,
                        options: item.options,
                        externalApi: item.externalApi,
                        explorers: item.explorers,
                        order: item.order,
                        additional: item.additional
                    )
                } else {
                    chainModel = item
                }
                mapping[item.chainId] = chainModel
            }

            let localChains = try localFetchOperation.extractNoCancellableResultData()
            let localMapping = localChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }

            let newOrUpdated: [ChainModel] = remoteChains.compactMap { remoteItem in
                if let localItem = localMapping[remoteItem.chainId] {
                    return localItem != remoteItem ? remoteItem : nil
                } else {
                    return remoteItem
                }
            }

            let removed = localChains.compactMap { localItem in
                remoteMapping[localItem.chainId] == nil ? localItem : nil
            }

            return SyncChanges(newOrUpdatedItems: newOrUpdated, removedItems: removed)
        }

        evmTokensProcessingOperation.addDependency(evmRemoteFetchOperation)
        processingOperation.addDependency(remoteFetchOperation)
        processingOperation.addDependency(evmTokensProcessingOperation)
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
            remoteFetchOperation, localFetchOperation, processingOperation, localSaveOperation, mapOperation
        ], waitUntilFinished: false)
    }

    private static func createAssets(evmTokens tokens: [RemoteEvmToken]) -> [ChainModel.Id: Set<AssetModel>] {
        var result = [ChainModel.Id: Set<AssetModel>]()

        for token in tokens {
            for instance in token.instances {
                guard let asset = AssetModel(evmToken: token, evmInstance: instance) else {
                    continue
                }
                var assets = result[instance.chainId] ?? Set<AssetModel>()
                assets.insert(asset)
                result[instance.chainId] = assets
            }
        }

        return result
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
