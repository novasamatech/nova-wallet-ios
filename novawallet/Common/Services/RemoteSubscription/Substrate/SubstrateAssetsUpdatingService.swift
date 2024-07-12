import Foundation

final class SubstrateAssetsUpdatingService: AssetBalanceBatchBaseUpdatingService {
    private let remoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol
    private let repositoryFactory: SubstrateRepositoryFactoryProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let eventCenter: EventCenterProtocol
    private let operationQueue: OperationQueue

    private var subscribedAssets: [ChainModel.Id: Set<AssetModel.Id>] = [:]

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.remoteSubscriptionService = remoteSubscriptionService
        self.operationQueue = operationQueue
        self.repositoryFactory = repositoryFactory
        self.storageRequestFactory = storageRequestFactory
        self.eventCenter = eventCenter

        super.init(
            selectedAccount: selectedAccount,
            chainRegistry: chainRegistry,
            logger: logger
        )
    }

    override func updateSubscription(for chain: ChainModel) {
        guard chain.isFullSyncMode else {
            removeSubscription(for: chain.chainId)
            return
        }

        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            return
        }

        let newAssets = chain.assets.filter { $0.enabled }
        let newAssetIds = Set(newAssets.map(\.assetId))

        guard subscribedAssets[chain.chainId] != newAssetIds else {
            logger.debug("Assets didn't change for chain \(chain.name)")
            return
        }

        removeSubscription(for: chain.chainId)

        guard let anyAsset = chain.assets.first(where: { newAssetIds.contains($0.assetId) }) else {
            logger.debug("No assets found for chain \(chain.name)")
            return
        }

        let transactionSubscription = try? createTransactionSubscription(for: accountId, chain: chain)

        guard
            let subscriptionId = remoteSubscriptionService.attachToBalances(
                for: accountId,
                chain: chain,
                transactionSubscription: transactionSubscription,
                onlyFor: newAssetIds,
                queue: nil,
                closure: nil
            ) else {
            logger.error("No balances subscription for \(chain.name)")
            return
        }

        let subscription = SubscriptionInfo(
            subscriptionId: subscriptionId,
            accountId: accountId,
            asset: anyAsset
        )

        setSubscriptions(for: chain.chainId, subscriptions: [anyAsset.assetId: subscription])

        subscribedAssets[chain.chainId] = newAssetIds
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

        remoteSubscriptionService.detachFromBalances(
            for: subscription.subscriptionId,
            accountId: subscription.accountId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }

    private func createTransactionSubscription(
        for accountId: AccountId,
        chain: ChainModel
    ) throws -> TransactionSubscription {
        let address = try accountId.toAddress(using: chain.chainFormat)
        let txStorage = repositoryFactory.createChainAddressTxRepository(
            for: address,
            chainId: chain.chainId
        )

        return TransactionSubscription(
            chainRegistry: chainRegistry,
            accountId: accountId,
            chainModel: chain,
            txStorage: txStorage,
            storageRequestFactory: storageRequestFactory,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            logger: logger
        )
    }
}
