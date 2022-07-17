import Foundation
import SubstrateSdk
import RobinHood

final class RMRKV1SyncService: BaseNftSyncService {
    let ownerId: AccountId
    let chain: ChainModel

    private lazy var operationFactory = RMRKV1OperationFactory()

    init(
        ownerId: AccountId,
        chain: ChainModel,
        repository: AnyDataProviderRepository<NftModel>,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.ownerId = ownerId
        self.chain = chain

        super.init(
            repository: repository,
            operationQueue: operationQueue,
            retryStrategy: retryStrategy,
            logger: logger
        )
    }

    private func createCollectionsFetchWrapper(
        dependingOn itemsOperation: BaseOperation<[RMRKNftV1]>
    ) -> BaseOperation<[RMRKV1Collection]> {
        OperationCombiningService<RMRKV1Collection>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            let items = try itemsOperation.extractNoCancellableResultData()

            let collectionIds = Set(items.map(\.collectionId))

            return collectionIds.compactMap {
                guard let fetchOperation = self?.operationFactory.fetchCollection(for: $0) else {
                    return nil
                }

                let mapOperation = ClosureOperation<RMRKV1Collection> {
                    guard let collection = try fetchOperation.extractNoCancellableResultData().first else {
                        throw CommonError.dataCorruption
                    }

                    return collection
                }

                mapOperation.addDependency(fetchOperation)

                return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
            }
        }.longrunOperation()
    }

    override func createRemoteFetchWrapper() -> CompoundOperationWrapper<[RemoteNftModel]> {
        do {
            let ownerId = self.ownerId
            let address = try ownerId.toAddress(using: chain.chainFormat)
            let chainId = chain.chainId

            let itemsOperation = operationFactory.fetchNfts(for: address)

            let collectionsOperation = createCollectionsFetchWrapper(dependingOn: itemsOperation)

            collectionsOperation.addDependency(itemsOperation)

            let mapOperation = ClosureOperation<[RemoteNftModel]> {
                let remoteItems = try itemsOperation.extractNoCancellableResultData()

                let collections = try collectionsOperation.extractNoCancellableResultData()
                let collectionsDict = collections.reduce(into: [String: RMRKV1Collection]()) { result, item in
                    result[item.identifier] = item
                }

                return remoteItems.map { remoteItem in
                    RemoteNftModel.createFromRMRKV1(
                        remoteItem,
                        ownerId: ownerId,
                        chainId: chainId,
                        collection: collectionsDict[remoteItem.collectionId]
                    )
                }
            }

            mapOperation.addDependency(collectionsOperation)

            let dependencies = [itemsOperation, collectionsOperation]

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
