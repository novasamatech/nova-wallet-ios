import Foundation

extension TransactionHistoryLocalFilterFactory {
    static func createFromKnownProviders(
        for chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> TransactionHistoryLocalFilterFactory {
        TransactionHistoryLocalFilterFactory(
            providers: [
                ConstantHistoryFiltersProvider(filters: [TransactionHistoryPhishingFilter()]),
                PoolStakingHistoryFiltersProvider(chainAsset: chainAsset, chainRegistry: chainRegistry),
                MythosHistoryFiltersProvider(
                    chainAsset: chainAsset,
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                )
            ],
            logger: logger
        )
    }
}
