import Foundation
import RobinHood

protocol AccountInfoUpdatingServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class AccountInfoUpdatingService {
    struct SubscriptionInfo {
        let subscriptionId: UUID
        let accountId: AccountId
    }

    private(set) var selectedMetaAccount: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    let eventCenter: EventCenterProtocol
    let storageFacade: StorageFacadeProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var subscribedChains: [ChainModel.Id: SubscriptionInfo] = [:]

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
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        selectedMetaAccount = selectedAccount
        self.chainRegistry = chainRegistry
        self.remoteSubscriptionService = remoteSubscriptionService
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.storageRequestFactory = storageRequestFactory
        self.operationQueue = operationQueue
        self.logger = logger
        repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
    }

    private func removeAllSubscriptions() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        for chainId in subscribedChains.keys {
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

    private func checkSubscription(for chainId: ChainModel.Id) -> Bool {
        subscribedChains[chainId] != nil
    }

    private func checkChainReadyForSubscription(_ chain: ChainModel) -> Bool {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return false
        }

        return runtimeProvider.hasSnapshot
    }

    private func updateSubscription(for chain: ChainModel) {
        let hasSubscription = checkSubscription(for: chain.chainId)

        guard let asset = chain.utilityAssets().first(where: { $0.type == nil }) else {
            logger.warning("Native asset not found for chain \(chain.chainId)")

            if hasSubscription {
                removeSubscription(for: chain.chainId)
            }

            return
        }

        guard checkChainReadyForSubscription(chain) else {
            return
        }

        if asset.enabled, !hasSubscription {
            addSubscription(for: chain, asset: asset)
        } else if hasSubscription, !asset.enabled {
            removeSubscription(for: chain.chainId)
        }
    }

    private func addSubscription(for chain: ChainModel, asset: AssetModel) {
        guard
            let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId,
            let address = try? accountId.toAddress(using: chain.chainFormat) else {
            logger.warning("Couldn't create account for chain \(chain.chainId)")
            return
        }

        let txStorage = repositoryFactory.createChainAddressTxRepository(
            for: address,
            chainId: chain.chainId
        )

        let transactionSubscription = TransactionSubscription(
            chainRegistry: chainRegistry,
            accountId: accountId,
            chainModel: chain,
            txStorage: txStorage,
            storageRequestFactory: storageRequestFactory,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            logger: logger
        )

        let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
        let assetBalanceMapper = AssetBalanceMapper()
        let assetRepository = storageFacade.createRepository(mapper: AnyCoreDataMapper(assetBalanceMapper))
        let locksRepository = repositoryFactory.createAssetLocksRepository(
            for: accountId,
            chainAssetId: chainAssetId
        )

        let subscriptionHandlingFactory = TokenSubscriptionFactory(
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: AnyDataProviderRepository(assetRepository),
            locksRepository: AnyDataProviderRepository(locksRepository),
            eventCenter: eventCenter,
            transactionSubscription: transactionSubscription
        )

        let maybeSubscriptionId = remoteSubscriptionService.attachToAccountInfo(
            of: accountId,
            chainId: chain.chainId,
            chainFormat: chain.chainFormat,
            queue: nil,
            closure: nil,
            subscriptionHandlingFactory: subscriptionHandlingFactory
        )

        if let subsciptionId = maybeSubscriptionId {
            subscribedChains[chain.chainId] = SubscriptionInfo(
                subscriptionId: subsciptionId,
                accountId: accountId
            )
        }
    }

    private func removeSubscription(for chainId: ChainModel.Id) {
        guard let subscriptionInfo = subscribedChains[chainId] else {
            return
        }

        subscribedChains[chainId] = nil

        remoteSubscriptionService.detachFromAccountInfo(
            for: subscriptionInfo.subscriptionId,
            accountId: subscriptionInfo.accountId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
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

extension AccountInfoUpdatingService: AccountInfoUpdatingServiceProtocol {
    func setup() {
        subscribeToChains()

        eventCenter.add(observer: self)
    }

    func throttle() {
        unsubscribeFromChains()

        eventCenter.remove(observer: self)
    }

    func update(selectedMetaAccount: MetaAccountModel) {
        unsubscribeFromChains()

        self.selectedMetaAccount = selectedMetaAccount

        subscribeToChains()
    }
}

extension AccountInfoUpdatingService: EventVisitorProtocol {
    func processRuntimeCoderReady(event: RuntimeCoderCreated) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard
            !checkSubscription(for: event.chainId),
            let chain = chainRegistry.getChain(for: event.chainId) else {
            return
        }

        updateSubscription(for: chain)
    }
}
