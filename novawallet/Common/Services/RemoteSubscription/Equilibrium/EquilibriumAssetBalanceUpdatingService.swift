import Foundation

final class EquilibriumAssetBalanceUpdatingService: AssetBalanceBatchBaseUpdatingService {
    private let remoteSubscriptionService: EquillibriumRemoteSubscriptionServiceProtocol
    private let eventCenter: EventCenterProtocol
    private let operationQueue: OperationQueue
    private let repositoryFactory: SubstrateRepositoryFactoryProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol

    private var subscribedAssets: [ChainModel.Id: Set<AssetModel.Id>] = [:]

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: EquillibriumRemoteSubscriptionServiceProtocol,
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

        super.init(selectedAccount: selectedAccount, chainRegistry: chainRegistry, logger: logger)
    }

    override func updateSubscription(for chain: ChainModel) {
        guard chain.isFullSyncMode else {
            removeSubscription(for: chain.chainId)
            return
        }

        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            return
        }

        let newAssetsIds = chain
            .assets
            .reduce(into: [AssetModel.Id: EquilibriumAssetId]()) { result, asset in
                if asset.enabled, let equilibriumAssetId = asset.equilibriumAssetId {
                    result[asset.assetId] = equilibriumAssetId
                }
            }

        guard subscribedAssets[chain.chainId] != Set(newAssetsIds.keys) else {
            return
        }

        removeSubscription(for: chain.chainId)

        guard !newAssetsIds.isEmpty else {
            return
        }

        if let subscription = createSubscription(
            accountId: accountId,
            chain: chain,
            assets: newAssetsIds
        ) {
            setSubscriptions(for: chain.chainId, subscriptions: [subscription.asset.assetId: subscription])
            subscribedAssets[chain.chainId] = Set(newAssetsIds.keys)
        }
    }

    private func createSubscription(
        accountId: AccountId,
        chain: ChainModel,
        assets: [AssetModel.Id: EquilibriumAssetId]
    ) -> AssetBalanceBatchBaseUpdatingService.SubscriptionInfo? {
        guard let equilibriumAsset = chain.equilibriumAssets.first(where: {
            assets.keys.contains($0.assetId)
        }) else {
            return nil
        }
        guard let utilityChainAssetId = chain.utilityChainAssetId() else {
            return nil
        }
        let info = RemoteEquilibriumSubscriptionInfo(
            accountId: accountId,
            chain: chain,
            assets: Array(assets.values)
        )

        let chainAssetIds = Set(assets.map { ChainAssetId(chainId: chain.chainId, assetId: $0.key) })

        let repository = repositoryFactory.createAssetBalanceRepository(
            for: chainAssetIds
        )

        let locksRepository = repositoryFactory
            .createAssetLocksRepository(chainAssetIds: Set<ChainAssetId>([utilityChainAssetId]))

        let transactionSubscription = try? createTransactionSubscription(
            for: accountId,
            chain: chain
        )

        let balanceUpdater = EquillibriumAssetsBalanceUpdater(
            chainModel: chain,
            accountId: accountId,
            chainRegistry: chainRegistry,
            repository: repository,
            transactionSubscription: transactionSubscription,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        let locksUpdater = EquillibriumLocksUpdater(
            chainAssetId: utilityChainAssetId,
            accountId: accountId,
            repository: locksRepository,
            chainRegistry: chainRegistry,
            logger: logger,
            queue: operationQueue
        )

        guard let subscriptionId = remoteSubscriptionService.attachToEquilibriumAssets(
            info: info,
            balanceUpdater: balanceUpdater,
            locksUpdater: locksUpdater,
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
