import Foundation
import RobinHood

protocol AssetsUpdatingServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class AssetsUpdatingService {
    struct SubscriptionInfo {
        let subscriptionId: UUID
        let accountId: AccountId
        let asset: AssetModel
    }

    private(set) var selectedMetaAccount: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    let eventCenter: EventCenterProtocol
    let storageFacade: StorageFacadeProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    private var subscribedChains: [ChainModel.Id: [AssetModel.Id: SubscriptionInfo]] = [:]

    private let mutex = NSLock()

    deinit {
        removeAllSubscriptions()
    }

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        selectedMetaAccount = selectedAccount
        self.chainRegistry = chainRegistry
        self.remoteSubscriptionService = remoteSubscriptionService
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
        self.logger = logger
        repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
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

    private func addSubscriptionIfNeeded(for chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            logger.error("Couldn't create account for chain \(chain.chainId)")
            return
        }

        removeSubscription(for: chain.chainId)

        let assetSubscriptions = chain.assets.reduce(
            into: [AssetModel.Id: SubscriptionInfo]()
        ) { result, asset in
            result[asset.assetId] = createSubscription(for: asset, accountId: accountId, chainId: chain.chainId)
        }

        subscribedChains[chain.chainId] = assetSubscriptions
    }

    private func createSubscription(
        for asset: AssetModel,
        accountId: AccountId,
        chainId: ChainModel.Id
    ) -> SubscriptionInfo? {
        guard let typeString = asset.type, let assetType = AssetType(rawValue: typeString) else {
            return nil
        }

        switch assetType {
        case .statemine:
            guard
                let extras = asset.typeExtras,
                let assetExtras = try? extras.map(to: StatemineAssetExtras.self) else {
                return nil
            }

            let handlingFactory = EventRemoteSubscriptionHandlingFactory(eventCenter: eventCenter) { _ in
                WalletBalanceChanged()
            }

            let maybeSubscriptionId = remoteSubscriptionService.attachToAsset(
                of: accountId,
                assetId: assetExtras.assetId,
                chainId: chainId,
                queue: nil,
                closure: nil,
                subscriptionHandlingFactory: handlingFactory
            )

            if let subscriptionId = maybeSubscriptionId {
                return SubscriptionInfo(
                    subscriptionId: subscriptionId,
                    accountId: accountId,
                    asset: asset
                )
            } else {
                return nil
            }
        }
    }

    private func removeSubscription(for chainId: ChainModel.Id) {
        guard let assetSubscriptions = subscribedChains[chainId] else {
            logger.error("Expected to remove subscription but not found for \(chainId)")
            return
        }

        subscribedChains[chainId] = nil

        for subscriptionInfo in assetSubscriptions.values {
            let asset = subscriptionInfo.asset

            guard let typeString = asset.type, let assetType = AssetType(rawValue: typeString) else {
                return
            }

            switch assetType {
            case .statemine:
                guard
                    let extras = asset.typeExtras,
                    let assetExtras = try? extras.map(to: StatemineAssetExtras.self) else {
                    return
                }

                remoteSubscriptionService.detachFromAsset(
                    for: subscriptionInfo.subscriptionId,
                    accountId: subscriptionInfo.accountId,
                    assetId: assetExtras.assetId,
                    chainId: chainId,
                    queue: nil,
                    closure: nil
                )
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

extension AssetsUpdatingService: AssetsUpdatingServiceProtocol {
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
