import Foundation
import RobinHood

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
        address: AccountAddress,
        chainAsset: ChainAsset,
        pageSize: Int,
        filter _: WalletHistoryFilter
    ) -> TransactionHistoryRemoteFetcher {
        TransactionHistoryRemoteFetcher(
            address: address,
            chainAsset: chainAsset,
            operationFactory: remoteFactory,
            operationQueue: operationQueue,
            pageSize: pageSize
        )
    }

    private func createHybridFetch(
        from remoteFactory: WalletRemoteHistoryFactoryProtocol,
        address: AccountAddress,
        chainAsset: ChainAsset,
        pageSize: Int
    ) -> TransactionHistoryHybridFetcher {
        let localProvider = createLocalProvider(from: address, chainAsset: chainAsset, filter: .all)

        let repository = repositoryFactory.createTxRepository()

        return .init(
            address: address,
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
                return createHybridFetch(
                    from: remoteFactory,
                    address: address,
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
                    address: address,
                    chainAsset: chainAsset,
                    pageSize: pageSize,
                    filter: filter
                )
            } else {
                return createLocalFetcher(from: address, chainAsset: chainAsset, filter: filter)
            }
        }
    }
}
