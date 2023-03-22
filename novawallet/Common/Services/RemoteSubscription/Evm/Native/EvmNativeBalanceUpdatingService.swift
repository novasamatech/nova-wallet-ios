import Foundation

final class EvmNativeBalanceUpdatingService: AssetBalanceBatchBaseUpdatingService {
    let remoteSubscriptionService: WalletRemoteEvmSubscriptionServiceProtocol
    let transactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol

    private var subscribedAssets: [ChainModel.Id: AssetModel.Id] = [:]

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
        assetId: AssetModel.Id
    ) -> AssetBalanceBatchBaseUpdatingService.SubscriptionInfo? {
        guard let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return nil
        }

        let info = RemoteEvmNativeSubscriptionInfo(accountId: accountId, chain: chain, assetId: assetId)

        let optSubscriptionId = remoteSubscriptionService.attachNativeBalance(
            for: info,
            transactionHistoryUpdaterFactory: transactionHistoryUpdaterFactory,
            queue: nil,
            closure: nil
        )

        guard let subscriptionId = optSubscriptionId else {
            return nil
        }

        return .init(subscriptionId: subscriptionId, accountId: accountId, asset: asset)
    }

    override func updateSubscription(for chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            return
        }

        let optAssetId = chain.assets.first { asset in
            asset.isEvmNative && asset.enabled
        }?.assetId

        guard subscribedAssets[chain.chainId] != optAssetId else {
            return
        }

        removeSubscription(for: chain.chainId)

        guard let assetId = optAssetId else {
            return
        }

        if let subscription = createSubscription(accountId: accountId, chain: chain, assetId: assetId) {
            setSubscriptions(for: chain.chainId, subscriptions: [assetId: subscription])
            subscribedAssets[chain.chainId] = assetId
        }
    }

    override func removeSubscription(for chainId: ChainModel.Id) {
        guard let subscription = getSubscriptions(for: chainId)?.first?.value else {
            logger.warning("Expected to remove subscription but not found for \(chainId)")
            return
        }

        clearSubscriptions(for: chainId)

        remoteSubscriptionService.detachNativeBalance(
            for: subscription.subscriptionId,
            accountId: subscription.accountId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }
}
