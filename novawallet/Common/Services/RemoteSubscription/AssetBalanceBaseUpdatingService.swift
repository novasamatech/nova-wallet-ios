import Foundation
import RobinHood

class AssetBalanceBaseUpdatingService {
    struct SubscriptionInfo {
        let subscriptionId: UUID
        let accountId: AccountId
        let asset: AssetModel
    }

    private(set) var selectedMetaAccount: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol

    let mutex = NSLock()

    private var subscribedChains: [ChainModel.Id: [AssetModel.Id: SubscriptionInfo]] = [:]

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol
    ) {
        selectedMetaAccount = selectedAccount
        self.chainRegistry = chainRegistry
        self.logger = logger
    }

    func createSubscription(
        for _: AssetModel,
        accountId _: AccountId,
        chain _: ChainModel
    ) -> SubscriptionInfo? {
        fatalError("Must be implemented in child class")
    }

    func removeSubscription(for _: ChainModel.Id) {
        fatalError("Must be implemented in child class")
    }

    func clearSubscriptions(for chainId: ChainModel.Id) {
        subscribedChains[chainId] = nil
    }

    func getSubscriptions(for chainId: ChainModel.Id) -> [AssetModel.Id: SubscriptionInfo]? {
        subscribedChains[chainId]
    }

    private func addSubscriptionIfNeeded(for chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            logger.warning("Couldn't create account for chain \(chain.chainId)")
            return
        }

        removeSubscription(for: chain.chainId)

        let assetSubscriptions = chain.assets.reduce(
            into: [AssetModel.Id: SubscriptionInfo]()
        ) { result, asset in
            result[asset.assetId] = createSubscription(
                for: asset,
                accountId: accountId,
                chain: chain
            )
        }

        subscribedChains[chain.chainId] = assetSubscriptions
    }

    private func removeAllSubscriptions() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        for key in subscribedChains.keys {
            removeSubscription(for: key)
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        for change in changes {
            switch change {
            case let .insert(newItem):
                addSubscriptionIfNeeded(for: newItem)
            case .update:
                break
            case let .delete(deletedIdentifier):
                removeSubscription(for: deletedIdentifier)
            }
        }
    }

    private func subscribeToChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .global(qos: .userInitiated)
        ) { [weak self] changes in
            self?.handle(changes: changes)
        }
    }

    private func unsubscribeFromChains() {
        chainRegistry.chainsUnsubscribe(self)

        removeAllSubscriptions()
    }
}

extension AssetBalanceBaseUpdatingService: AssetsUpdatingServiceProtocol {
    func setup() {
        subscribeToChains()
    }

    func throttle() {
        unsubscribeFromChains()
    }

    func update(selectedMetaAccount: MetaAccountModel) {
        unsubscribeFromChains()

        self.selectedMetaAccount = selectedMetaAccount

        subscribeToChains()
    }
}
