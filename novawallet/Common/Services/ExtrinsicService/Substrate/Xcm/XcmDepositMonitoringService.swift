import Foundation
import Operation_iOS
import SubstrateSdk

protocol XcmDepositMonitoringServiceProtocol {
    func createMonitoringWrapper(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        timeout: TimeInterval
    ) -> CompoundOperationWrapper<Balance>
}

final class XcmDepositMonitoringService {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol
    let blockEventsQueryFactory: BlockEventsQueryFactoryProtocol

    private var subscription: WalletRemoteSubscriptionProtocol?

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

        blockEventsQueryFactory = BlockEventsQueryFactory(operationQueue: operationQueue, logger: logger)
    }

    private func fetchBlockAndDetectDeposit(for hash: Data) {
        let eventsWrapper = blockEventsQueryFactory.queryInherentEventsWrapper(
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: hash
        )
    }
}

extension XcmDepositMonitoringService: XcmDepositMonitoringServiceProtocol {
    func createMonitoringWrapper(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        timeout _: TimeInterval
    ) -> CompoundOperationWrapper<Balance> {
        subscription = WalletRemoteSubscription(
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )

        subscription?.subscribeBalance(
            for: accountId,
            chainAsset: chainAsset,
            callbackQueue: workingQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(update):
                guard let blockHash = update.blockHash else {
                    logger.debug("No block found in update")
                    return
                }

                fetchBlockAndDetectDeposit(for: blockHash)
            case let .failure(error):
                logger.error("Remote subscription failed: \(error)")
            }
        }

        return .createWithResult(0)
    }
}
