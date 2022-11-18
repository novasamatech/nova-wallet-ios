import Foundation

final class EvmAssetBalanceUpdatingService: AssetBalanceBaseUpdatingService {
    let remoteSubscriptionService: WalletRemoteEvmSubscriptionServiceProtocol

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: WalletRemoteEvmSubscriptionServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.remoteSubscriptionService = remoteSubscriptionService

        super.init(selectedAccount: selectedAccount, chainRegistry: chainRegistry, logger: logger)
    }

    override func createSubscription(
        for _: AssetModel,
        accountId: AccountId,
        chain: ChainModel
    ) -> AssetBalanceBaseUpdatingService.SubscriptionInfo? {
        guard getSubscriptions(for: chain.chainId) == nil else {
            // we are subscribing to all evm assets in the chain at once
            return nil
        }

        guard let evmAsset = chain.assets.first(where: { $0.type == "evm" }) else {
            return nil
        }

        let optSubscriptionId = remoteSubscriptionService.attachERC20Balance(
            for: accountId,
            chain: chain,
            queue: nil,
            closure: nil
        )

        guard let subscriptionId = optSubscriptionId else {
            return nil
        }

        return .init(subscriptionId: subscriptionId, accountId: accountId, asset: evmAsset)
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
