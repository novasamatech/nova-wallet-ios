import Foundation

final class SubstrateAssetsUpdatingService: AssetBalanceBatchBaseUpdatingService {
    private let remoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol
    private let eventCenter: EventCenterProtocol

    private var subscribedAssets: [ChainModel.Id: Set<AssetModel.Id>] = [:]

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.remoteSubscriptionService = remoteSubscriptionService
        self.eventCenter = eventCenter

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
        guard let typeString = asset.type else {
            return true
        }

        switch AssetType(rawValue: typeString) {
        case .statemine, .orml:
            return true
        case .evmAsset, .evmNative, .equilibrium, .ormlHydrationEvm, .none:
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
            logger.debug("Assets didn't change for chain \(chain.name)")
            return
        }

        removeSubscription(for: chain.chainId)

        guard let anyAsset = chain.assets.first(where: { newAssetIds.contains($0.assetId) }) else {
            logger.debug("No supported or enabled assets found for \(chain.name)")
            return
        }

        guard checkChainReadyForSubscription(chain) else {
            logger.debug("Skipping balance subscription for \(chain.name)")
            return
        }

        logger.debug("Subscribing balances for \(chain.name)")

        guard
            let subscriptionId = remoteSubscriptionService.attachToBalances(
                for: accountId,
                chain: chain,
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

    override func performSetup() {
        super.performSetup()

        eventCenter.add(observer: self)
    }

    override func performThrottle() {
        super.performThrottle()

        eventCenter.remove(observer: self)
    }
}

extension SubstrateAssetsUpdatingService: EventVisitorProtocol {
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
