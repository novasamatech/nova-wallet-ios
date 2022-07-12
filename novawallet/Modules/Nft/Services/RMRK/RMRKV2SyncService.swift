import Foundation
import SubstrateSdk
import RobinHood

final class RMRKV2SyncService: BaseNftSyncService {
    let ownerId: AccountId
    let chain: ChainModel

    private lazy var operationFactory = RMRKV2OperationFactory()

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

            let itemsOperation = operationFactory.fetchNfts(for: address)

            let mapOperation = ClosureOperation<[RemoteNftModel]> {
                let items = try itemsOperation.extractNoCancellableResultData()

                return items.map { remoteItem in
                    let identifier = NftModel.rmrkv2Identifier(
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
                        type: NftType.rmrkV2.rawValue,
                        chainId: chainId,
                        ownerId: ownerId,
                        collectionId: remoteItem.collectionId,
                        instanceId: nil,
                        metadata: metadata,
                        totalIssuance: nil,
                        name: remoteItem.symbol,
                        label: remoteItem.serialNumber,
                        media: remoteItem.image,
                        price: price
                    )
                }
            }

            mapOperation.addDependency(itemsOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [itemsOperation])
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
