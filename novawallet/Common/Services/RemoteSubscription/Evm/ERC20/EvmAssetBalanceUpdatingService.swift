import Foundation

final class EvmAssetBalanceUpdatingService: AssetBalanceBatchBaseUpdatingService {
    let remoteSubscriptionService: WalletRemoteEvmSubscriptionServiceProtocol
    let transactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol

    private var subscribedAssets: [ChainModel.Id: Set<AssetModel.Id>] = [:]

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: WalletRemoteEvmSubscriptionServiceProtocol,
        transactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.remoteSubscriptionService = remoteSubscriptionService
        self.transactionHistoryUpdaterFactory = transactionHistoryUpdaterFactory

        super.init(selectedAccount: selectedAccount, chainRegistry: chainRegistry, logger: logger)
    }

    override func clearSubscriptions(for chainId: ChainModel.Id) {
        super.clearSubscriptions(for: chainId)

        subscribedAssets[chainId] = nil
    }

    private func createSubscription(
        accountId: AccountId,
        chain: ChainModel,
        assetIds: Set<AssetModel.Id>
    ) -> AssetBalanceBatchBaseUpdatingService.SubscriptionInfo? {
        guard let evmAsset = chain.assets.first(where: { assetIds.contains($0.assetId) }) else {
            return nil
        }

        let info = RemoteEvmSubscriptionInfo(
            accountId: accountId,
            chain: chain,
            assets: assetIds
        )

        let optSubscriptionId = remoteSubscriptionService.attachERC20Balance(
            for: info,
            transactionHistoryUpdaterFactory: transactionHistoryUpdaterFactory,
            queue: nil,
            closure: nil
        )

        guard let subscriptionId = optSubscriptionId else {
            return nil
        }

        return .init(subscriptionId: subscriptionId, accountId: accountId, asset: evmAsset)
    }

    override func updateSubscription(for chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            return
        }

        let newAssetIdsList = chain.assets.compactMap { asset in
            if asset.isEvmAsset, asset.enabled {
                return asset.assetId
            } else {
                return nil
            }
        }

        let newAssetIds = Set(newAssetIdsList)

        guard subscribedAssets[chain.chainId] != newAssetIds else {
            return
        }

        removeSubscription(for: chain.chainId)

        guard !newAssetIds.isEmpty else {
            return
        }

        if let subscription = createSubscription(accountId: accountId, chain: chain, assetIds: newAssetIds) {
            setSubscriptions(for: chain.chainId, subscriptions: [subscription.asset.assetId: subscription])
            subscribedAssets[chain.chainId] = newAssetIds
        }
    }

    override func removeSubscription(for chainId: ChainModel.Id) {
        guard let subscription = getSubscriptions(for: chainId)?.first?.value else {
            logger.warning("Expected to remove subscription but not found for \(chainId)")
            return
        }

        clearSubscriptions(for: chainId)

        remoteSubscriptionService.detachERC20Balance(
            for: subscription.subscriptionId,
            accountId: subscription.accountId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }
}
