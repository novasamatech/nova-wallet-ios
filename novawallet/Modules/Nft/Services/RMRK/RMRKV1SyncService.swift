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

    override func createRemoteFetchWrapper() -> CompoundOperationWrapper<[RemoteNftModel]> {
        do {
            let ownerId = self.ownerId
            let address = try ownerId.toAddress(using: chain.chainFormat)
            let chainId = chain.chainId

            let fetchOperation = operationFactory.fetchNfts(for: address)

            let mapOperation = ClosureOperation<[RemoteNftModel]> {
                let remoteItems = try fetchOperation.extractNoCancellableResultData()

                return remoteItems.map { remoteItem in
                    let identifier = NftModel.rmrkv1Identifier(
                        for: chainId,
                        identifier: remoteItem.identifier
                    )

                    let metadata: Data?

                    if let metadataString = remoteItem.metadata {
                        metadata = metadataString.data(using: .utf8)
                    } else {
                        metadata = nil
                    }

                    let price = remoteItem.forsale.map(\.stringWithPointSeparator)

                    return RemoteNftModel(
                        identifier: identifier,
                        type: NftType.rmrkV1.rawValue,
                        chainId: chainId,
                        ownerId: ownerId,
                        collectionId: remoteItem.collectionId,
                        instanceId: remoteItem.instance,
                        metadata: metadata,
                        totalIssuance: remoteItem.collection?.max,
                        name: remoteItem.name,
                        label: remoteItem.serialNumber,
                        media: nil,
                        price: price
                    )
                }
            }

            mapOperation.addDependency(fetchOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
