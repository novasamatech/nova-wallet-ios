import Foundation
import SubstrateSdk
import RobinHood

enum Pdc20NftSyncServiceError: Error {
    case unsupported(String)
}

final class Pdc20NftSyncService: BaseNftSyncService {
    let ownerId: AccountId
    let chain: ChainModel

    private let operationFactory = Pdc20NftOperationFactory(url: Pdc20Api.url)

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
            let address = try ownerId.toAddress(using: chain.chainFormat)

            guard let network = chain.pdc20Network else {
                throw Pdc20NftSyncServiceError.unsupported(chain.name)
            }

            let fetchWrapper = operationFactory.fetchNfts(for: address, network: network)

            let mapOperation = ClosureOperation<[RemoteNftModel]> {
                let response = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                return try Pdc20NftModelConverter.convert(response: response, chain: self.chain)
            }

            mapOperation.addDependency(fetchWrapper.targetOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: fetchWrapper.allOperations)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
