import Foundation

final class OrmlHydrationEvmWalletSyncService: AssetBalanceBatchBaseUpdatingService {
    private let eventCenter: EventCenterProtocol
    private let syncServiceFactory: OrmlHydrationEvmWalletSyncFactoryProtocol

    private var subscribedAssets: [ChainModel.Id: Set<AssetModel.Id>] = [:]
    private var syncSevices: [UUID: ApplicationServiceProtocol] = [:]

    init(
        selectedAccount: MetaAccountModel,
        syncServiceFactory: OrmlHydrationEvmWalletSyncFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.eventCenter = eventCenter
        self.syncServiceFactory = syncServiceFactory

        super.init(
            selectedAccount: selectedAccount,
            chainRegistry: chainRegistry,
            logger: logger
        )
    }

    private func checkChainReadyForSubscription(_ chain: ChainModel) -> Bool {
        guard
            chain.isFullSyncMode,
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return false
        }

        return runtimeProvider.hasSnapshot
    }

    private func supportsAssetSubscription(for asset: AssetModel) -> Bool {
        switch AssetType(rawType: asset.type) {
        case .ormlHydrationEvm:
            return true
        default:
            return false
        }
    }

    override func updateSubscription(for chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            removeSubscription(for: chain.chainId)
            return
        }

        let newAssets = chain.assets.filter { $0.enabled && supportsAssetSubscription(for: $0) }
        let newAssetIds = Set(newAssets.map(\.assetId))

        guard subscribedAssets[chain.chainId] != newAssetIds else {
            logger.debug("Assets didn't change")
            return
        }

        removeSubscription(for: chain.chainId)

        guard let anyAsset = chain.assets.first(where: { newAssetIds.contains($0.assetId) }) else {
            logger.debug("No supported or enabled assets")
            return
        }

        guard checkChainReadyForSubscription(chain) else {
            logger.debug("Skipping balance subscription for \(chain.name)")
            return
        }

        logger.debug("Subscribing balances for \(newAssetIds)")

        let subscriptionId = UUID()
        let service = syncServiceFactory.createSyncService(for: chain.chainId, accountId: accountId)

        let subscription = SubscriptionInfo(
            subscriptionId: subscriptionId,
            accountId: accountId,
            asset: anyAsset
        )

        setSubscriptions(for: chain.chainId, subscriptions: [anyAsset.assetId: subscription])

        subscribedAssets[chain.chainId] = newAssetIds
        syncSevices[subscriptionId] = service

        service.setup()
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

        syncSevices[subscription.subscriptionId]?.throttle()
        syncSevices[subscription.subscriptionId] = nil
    }

    override func performSetup() {
        super.performSetup()

        eventCenter.add(observer: self)
    }

    override func performThrottle() {
        super.performThrottle()

        eventCenter.remove(observer: self)
    }
}

extension OrmlHydrationEvmWalletSyncService: EventVisitorProtocol {
    func processRuntimeCoderReady(event: RuntimeCoderCreated) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let hasSubscription = getSubscriptions(for: event.chainId) != nil

        guard
            !hasSubscription,
            let chain = chainRegistry.getChain(for: event.chainId) else {
            return
        }

        updateSubscription(for: chain)
    }
}
