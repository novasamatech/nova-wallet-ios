import Foundation
import Operation_iOS

protocol TransactionHistoryFetcherFactoryProtocol {
    func createFetcher(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        pageSize: Int,
        filter: WalletHistoryFilter
    ) throws -> TransactionHistoryFetching?
}

final class TransactionHistoryFetcherFactory {
    let remoteHistoryFacade: AssetHistoryFactoryFacadeProtocol
    let providerFactory: TransactionLocalSubscriptionFactoryProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let operationQueue: OperationQueue

    init(
        remoteHistoryFacade: AssetHistoryFactoryFacadeProtocol,
        providerFactory: TransactionLocalSubscriptionFactoryProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.remoteHistoryFacade = remoteHistoryFacade
        self.providerFactory = providerFactory
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
    }

    private func createLocalProvider(
        from address: AccountAddress,
        chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> StreamableProvider<TransactionHistoryItem> {
        let source = TransactionHistoryItemSource(assetTypeString: chainAsset.asset.type)

        let optimizedFilter = filter != .all ? filter : nil

        if chainAsset.isUtilityAsset {
            return providerFactory.getUtilityAssetTransactionsProvider(
                for: source,
                address: address,
                chainAssetId: chainAsset.chainAssetId,
                filter: optimizedFilter
            )
        } else {
            return providerFactory.getCustomAssetTransactionsProvider(
                for: source,
                address: address,
                chainAssetId: chainAsset.chainAssetId,
                filter: optimizedFilter
            )
        }
    }

    private func createLocalFetcher(
        from address: AccountAddress,
        chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> TransactionHistoryLocalFetcher {
        let localProvider = createLocalProvider(from: address, chainAsset: chainAsset, filter: filter)

        return TransactionHistoryLocalFetcher(provider: localProvider)
    }

    private func createRemoteFetcher(
        from remoteFactory: WalletRemoteHistoryFactoryProtocol,
        accountId: AccountId,
        chainAsset: ChainAsset,
        pageSize: Int
    ) -> TransactionHistoryRemoteFetcher {
        TransactionHistoryRemoteFetcher(
            accountId: accountId,
            chainAsset: chainAsset,
            operationFactory: remoteFactory,
            operationQueue: operationQueue,
            pageSize: pageSize
        )
    }

    private func createHybridFetch(
        from remoteFactory: WalletRemoteHistoryFactoryProtocol,
        accountId: AccountId,
        chainAsset: ChainAsset,
        pageSize: Int
    ) throws -> TransactionHistoryHybridFetcher {
        let address = try accountId.toAddress(using: chainAsset.chain.chainFormat)

        let localProvider = createLocalProvider(
            from: address,
            chainAsset: chainAsset,
            filter: .all
        )
        let source = TransactionHistoryItemSource(assetTypeString: chainAsset.asset.type)

        let repository: AnyDataProviderRepository<TransactionHistoryItem>

        if chainAsset.isUtilityAsset {
            repository = repositoryFactory.createUtilityAssetTxRepository(
                for: address,
                chainId: chainAsset.chain.chainId,
                assetId: chainAsset.asset.assetId,
                source: source
            )
        } else {
            repository = repositoryFactory.createCustomAssetTxRepository(
                for: address,
                chainId: chainAsset.chain.chainId,
                assetId: chainAsset.asset.assetId,
                source: source
            )
        }

        return .init(
            accountId: accountId,
            chainAsset: chainAsset,
            remoteOperationFactory: remoteFactory,
            repository: repository,
            provider: localProvider,
            operationQueue: operationQueue,
            pageSize: pageSize
        )
    }
}

extension TransactionHistoryFetcherFactory: TransactionHistoryFetcherFactoryProtocol {
    func createFetcher(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        pageSize: Int,
        filter: WalletHistoryFilter
    ) throws -> TransactionHistoryFetching? {
        let optRemoteFactory = remoteHistoryFacade.createOperationFactory(for: chainAsset, filter: filter)

        let address = try accountId.toAddress(using: chainAsset.chain.chainFormat)

        if filter == .all {
            if let remoteFactory = optRemoteFactory {
                return try createHybridFetch(
                    from: remoteFactory,
                    accountId: accountId,
                    chainAsset: chainAsset,
                    pageSize: pageSize
                )
            } else {
                return createLocalFetcher(from: address, chainAsset: chainAsset, filter: filter)
            }
        } else {
            if let remoteFactory = optRemoteFactory {
                return createRemoteFetcher(
                    from: remoteFactory,
                    accountId: accountId,
                    chainAsset: chainAsset,
                    pageSize: pageSize
                )
            } else {
                return createLocalFetcher(from: address, chainAsset: chainAsset, filter: filter)
            }
        }
    }
}
