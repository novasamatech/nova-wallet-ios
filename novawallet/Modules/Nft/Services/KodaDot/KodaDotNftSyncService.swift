import Foundation
import SubstrateSdk
import RobinHood

final class KodaDotNftSyncService: BaseNftSyncService {
    let ownerId: AccountId
    let chain: ChainModel

    private let operationFactory: KodaDotNftOperationFactoryProtocol

    init(
        api: URL,
        ownerId: AccountId,
        chain: ChainModel,
        repository: AnyDataProviderRepository<NftModel>,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.ownerId = ownerId
        self.chain = chain
        operationFactory = KodaDotNftOperationFactory(url: api)

        super.init(
            repository: repository,
            operationQueue: operationQueue,
            retryStrategy: retryStrategy,
            logger: logger
        )
    }

    private func createRemoteFetchWrapper(
        for chain: ChainModel,
        ownerId: AccountId
    ) -> CompoundOperationWrapper<[RemoteNftModel]> {
        do {
            let address = try ownerId.toAddress(using: chain.chainFormat)

            let fetchWrapper = operationFactory.fetchNfts(for: address)

            let mapOperation = ClosureOperation<[RemoteNftModel]> {
                let response = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                return try KodaDotNftModelConverter.convert(response: response, chain: chain)
            }

            mapOperation.addDependency(fetchWrapper.targetOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: fetchWrapper.allOperations)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    override func createRemoteFetchWrapper() -> CompoundOperationWrapper<[RemoteNftModel]> {
        createRemoteFetchWrapper(for: chain, ownerId: ownerId)
    }
}
