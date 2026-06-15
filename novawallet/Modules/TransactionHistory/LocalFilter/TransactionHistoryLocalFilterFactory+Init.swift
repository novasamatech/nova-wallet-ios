import Foundation

extension TransactionHistoryLocalFilterFactory {
    static func createFromKnownProviders(
        for chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> TransactionHistoryLocalFilterFactory {
        var constantFilters: [TransactionHistoryLocalFilterProtocol] = [
            TransactionHistoryPhishingFilter()
        ]

        if chainAsset.chain.hasSwapHydra {
            constantFilters.append(HydrationSwapAccountsFilter())
        }

        return TransactionHistoryLocalFilterFactory(
            providers: [
                ConstantHistoryFiltersProvider(filters: constantFilters),
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
