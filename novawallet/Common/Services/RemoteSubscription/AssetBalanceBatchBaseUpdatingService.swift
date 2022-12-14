import Foundation
import RobinHood

class AssetBalanceBatchBaseUpdatingService {
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

    func clearSubscriptions(for chainId: ChainModel.Id) {
        subscribedChains[chainId] = nil
    }

    func setSubscriptions(for chainId: ChainModel.Id, subscriptions: [AssetModel.Id: SubscriptionInfo]) {
        subscribedChains[chainId] = subscriptions
    }

    func getSubscriptions(for chainId: ChainModel.Id) -> [AssetModel.Id: SubscriptionInfo]? {
        subscribedChains[chainId]
    }

    func updateSubscription(for _: ChainModel) {
        fatalError("Must be implemented in child class")
    }

    func removeSubscription(for _: ChainModel.Id) {
        fatalError("Must be implemented in child class")
    }

    private func removeAllSubscriptions() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let chainIds = subscribedChains.keys
        for chainId in chainIds {
            removeSubscription(for: chainId)
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        for change in changes {
            switch change {
            case let .insert(newItem), let .update(newItem):
                updateSubscription(for: newItem)
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

extension AssetBalanceBatchBaseUpdatingService: AssetsUpdatingServiceProtocol {
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
