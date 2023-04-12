import Foundation

final class EquilibriumAssetBalanceUpdatingService: AssetBalanceBatchBaseUpdatingService {
    let remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let repositoryFactory: SubstrateRepositoryFactoryProtocol

    private var subscribedAssets: [ChainModel.Id: Set<AssetModel.Id>] = [:]

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.remoteSubscriptionService = remoteSubscriptionService
        self.operationQueue = operationQueue
        self.repositoryFactory = repositoryFactory
        self.eventCenter = eventCenter

        super.init(selectedAccount: selectedAccount, chainRegistry: chainRegistry, logger: logger)
    }

    override func updateSubscription(for chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            return
        }

        let newAssetIds = Set(
            chain
                .assets
                .filter { $0.isEquilibriumAsset && $0.enabled }
                .map(\.assetId)
        )

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

    private func createSubscription(
        accountId: AccountId,
        chain: ChainModel,
        assetIds: Set<AssetModel.Id>
    ) -> AssetBalanceBatchBaseUpdatingService.SubscriptionInfo? {
        guard let equilibriumAsset = chain.assets.first(where: { assetIds.contains($0.assetId) }) else {
            return nil
        }

        let info = RemoteEquilibriumSubscriptionInfo(
            accountId: accountId,
            chain: chain,
            assets: assetIds
        )

        let chainAssetIds = Set(assetIds.map { ChainAssetId(chainId: chain.chainId, assetId: $0) })

        let repository = repositoryFactory.createAssetBalanceRepository(
            for: chainAssetIds
        )

        let balanceUpdater = EquillibriumAssetsBalanceUpdater(
            chainModel: chain,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: repository,
            transactionSubscription: nil,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        guard let subscriptionId = remoteSubscriptionService.attachToEquilibriumAssets(
            info: info,
            balanceUpdater: balanceUpdater,
            queue: nil,
            closure: nil
        ) else {
            return nil
        }

        return .init(subscriptionId: subscriptionId, accountId: accountId, asset: equilibriumAsset)
    }

    override func clearSubscriptions(for chainId: ChainModel.Id) {
        super.clearSubscriptions(for: chainId)

        subscribedAssets[chainId] = nil
    }

    override func removeSubscription(for chainId: ChainModel.Id) {
        guard let subscription = getSubscriptions(for: chainId)?.first?.value else {
            logger.warning("Expected to remove subscription but not found for \(chainId)")
            return
        }

        clearSubscriptions(for: chainId)

        remoteSubscriptionService.detachFromEquilibriumAssets(
            for: subscription.subscriptionId,
            accountId: subscription.accountId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }
}
