import Foundation
import SubstrateSdk
import Operation_iOS

final class UniqueNftSyncService: BaseNftSyncService {
    let ownerId: AccountId
    let chain: ChainModel
    let operationFactory: UniqueNftOperationFactoryProtocol

    init(
        api: URL,
        ownerId: AccountId,
        chain: ChainModel,
        repository: AnyDataProviderRepository<NftModel>,
        operationQueue: OperationQueue
    ) {
        self.ownerId = ownerId
        self.chain = chain
        operationFactory = UniqueNftOperationFactory(apiBase: api)
        super.init(
            repository: repository,
            operationQueue: operationQueue,
            retryStrategy: ExponentialReconnection(),
            logger: Logger.shared
        )
    }

    override func createRemoteFetchWrapper() -> CompoundOperationWrapper<[RemoteNftModel]> {
        do {
            let address = try ownerId.toAddress(using: chain.chainFormat)
            let fetchWrapper = operationFactory.fetchNfts(for: address, offset: 0, limit: 20)

            let chainRef = chain
            let mapOp = ClosureOperation<[RemoteNftModel]> {
                let resp = try fetchWrapper.targetOperation.extractNoCancellableResultData()
                let models = try UniqueNftModelConverter.convert(response: resp, chain: chainRef)
                return models
            }
            mapOp.addDependency(fetchWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOp,
                dependencies: fetchWrapper.allOperations
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
