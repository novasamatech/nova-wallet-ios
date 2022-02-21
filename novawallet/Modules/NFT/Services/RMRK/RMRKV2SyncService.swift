import Foundation
import SubstrateSdk
import RobinHood

final class RMRKV2SyncService: BaseNftSyncService {
    let chain: ChainModel
    let repository: AnyDataProviderRepository<NftModel>
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        repository: AnyDataProviderRepository<NftModel>,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = Logger.shared
    ) {
        self.chain = chain
        self.repository = repository
        self.operationQueue = operationQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }
}
