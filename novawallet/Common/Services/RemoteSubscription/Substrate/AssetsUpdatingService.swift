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
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue
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
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        selectedMetaAccount = selectedAccount
        self.chainRegistry = chainRegistry
        self.remoteSubscriptionService = remoteSubscriptionService
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
        guard checkChainReadyForSubscription(chain) else {
            return
        }

        chain.assets.forEach { asset in
            guard supportsAssetSubscription(for: asset) else {
                return
            }

            let subscribed = hasSubscription(for: chain.chainId, assetId: asset.assetId)

            if !subscribed, asset.enabled {
                addSubscriptionIfNeeded(for: ChainAsset(chain: chain, asset: asset))
            } else if subscribed, !asset.enabled {
                dropSubscriptionIfNeeded(for: chain.chainId, assetId: asset.assetId)
            }
        }
    }

    private func hasSubscription(for chainId: ChainModel.Id, assetId: AssetModel.Id) -> Bool {
        let chainSubscription = subscribedChains[chainId]

        return chainSubscription?[assetId] != nil
    }

    private func supportsAssetSubscription(for asset: AssetModel) -> Bool {
        guard let typeString = asset.type, let assetType = AssetType(rawValue: typeString) else {
            return false
        }

        switch assetType {
        case .statemine, .orml:
            return true
        case .evm, .evmNative:
            return false
        }
    }

    private func addSubscriptionIfNeeded(for chainAsset: ChainAsset) {
        let chain = chainAsset.chain
        let chainId = chainAsset.chain.chainId
        let assetId = chainAsset.asset.assetId

        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            logger.warning("Couldn't create account for chain \(chainId)")
            return
        }

        guard !hasSubscription(for: chainId, assetId: assetId) else {
            return
        }

        var assetSubscriptions = subscribedChains[chainId] ?? [:]
        assetSubscriptions[assetId] = createSubscription(
            for: chainAsset.asset,
            accountId: accountId,
            chain: chain
        )

        subscribedChains[chain.chainId] = assetSubscriptions
    }

    private func dropSubscriptionIfNeeded(for chainId: ChainModel.Id, assetId: AssetModel.Id) {
        var chainSubscriptions = subscribedChains[chainId]
        let optSubsription = chainSubscriptions?[assetId]

        if let subscription = optSubsription {
            chainSubscriptions?[assetId] = nil
            subscribedChains[chainId] = chainSubscriptions

            removeSubscription(for: chainId, subscriptionInfo: subscription)
        }
    }

    private func createSubscription(
        for asset: AssetModel,
        accountId: AccountId,
        chain: ChainModel
    ) -> SubscriptionInfo? {
        guard let typeString = asset.type, let assetType = AssetType(rawValue: typeString) else {
            return nil
        }

        switch assetType {
        case .statemine:
            let transactionSubscription = try? createTransactionSubscription(for: accountId, chain: chain)

            return createStatemineSubscription(
                for: asset,
                accountId: accountId,
                chainId: chain.chainId,
                transactionSubscription: transactionSubscription
            )
        case .orml:
            let transactionSubscription = try? createTransactionSubscription(for: accountId, chain: chain)

            return createOrmlTokenSubscription(
                for: asset,
                accountId: accountId,
                chainId: chain.chainId,
                transactionSubscription: transactionSubscription
            )
        case .evm, .evmNative:
            return nil
        }
    }

    private func createStatemineSubscription(
        for asset: AssetModel,
        accountId: AccountId,
        chainId: ChainModel.Id,
        transactionSubscription: TransactionSubscription?
    ) -> SubscriptionInfo? {
        guard
            let extras = asset.typeExtras,
            let assetExtras = try? extras.map(to: StatemineAssetExtras.self) else {
            return nil
        }

        let assetRepository = repositoryFactory.createAssetBalanceRepository()
        let chainAssetId = ChainAssetId(chainId: chainId, assetId: asset.assetId)

        let assetBalanceUpdater = AssetsBalanceUpdater(
            chainAssetId: chainAssetId,
            accountId: accountId,
            extras: assetExtras,
            chainRegistry: chainRegistry,
            assetRepository: assetRepository,
            transactionSubscription: transactionSubscription,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        let maybeSubscriptionId = remoteSubscriptionService.attachToAsset(
            of: accountId,
            extras: assetExtras,
            chainId: chainId,
            queue: nil,
            closure: nil,
            assetBalanceUpdater: assetBalanceUpdater,
            transactionSubscription: transactionSubscription
        )

        return maybeSubscriptionId.map { subscriptionId in
            SubscriptionInfo(subscriptionId: subscriptionId, accountId: accountId, asset: asset)
        }
    }

    private func createOrmlTokenSubscription(
        for asset: AssetModel,
        accountId: AccountId,
        chainId: ChainModel.Id,
        transactionSubscription: TransactionSubscription?
    ) -> SubscriptionInfo? {
        guard
            let extras = asset.typeExtras,
            let tokenExtras = try? extras.map(to: OrmlTokenExtras.self),
            let currencyId = try? Data(hexString: tokenExtras.currencyIdScale) else {
            return nil
        }

        let chainAssetId = ChainAssetId(chainId: chainId, assetId: asset.assetId)
        let assetsRepository = repositoryFactory.createAssetBalanceRepository()
        let locksRepository = repositoryFactory.createAssetLocksRepository(for: accountId, chainAssetId: chainAssetId)
        let subscriptionHandlingFactory = TokenSubscriptionFactory(
            chainAssetId: chainAssetId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: assetsRepository,
            locksRepository: locksRepository,
            eventCenter: eventCenter,
            transactionSubscription: transactionSubscription
        )

        let maybeSubscriptionId = remoteSubscriptionService.attachToOrmlToken(
            of: accountId,
            currencyId: currencyId,
            chainId: chainId,
            queue: nil,
            closure: nil,
            subscriptionHandlingFactory: subscriptionHandlingFactory
        )

        return maybeSubscriptionId.map { subscriptionId in
            SubscriptionInfo(subscriptionId: subscriptionId, accountId: accountId, asset: asset)
        }
    }

    private func removeSubscription(for chainId: ChainModel.Id) {
        guard let assetSubscriptions = subscribedChains[chainId] else {
            logger.warning("Expected to remove subscription but not found for \(chainId)")
            return
        }

        subscribedChains[chainId] = nil

        for subscriptionInfo in assetSubscriptions.values {
            removeSubscription(for: chainId, subscriptionInfo: subscriptionInfo)
        }
    }

    private func removeSubscription(for chainId: ChainModel.Id, subscriptionInfo: SubscriptionInfo) {
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
                extras: assetExtras,
                chainId: chainId,
                queue: nil,
                closure: nil
            )
        case .orml:
            guard
                let extras = asset.typeExtras,
                let assetExtras = try? extras.map(to: OrmlTokenExtras.self),
                let currencyId = try? Data(hexString: assetExtras.currencyIdScale) else {
                return
            }

            remoteSubscriptionService.detachFromOrmlToken(
                for: subscriptionInfo.subscriptionId,
                accountId: subscriptionInfo.accountId,
                currencyId: currencyId,
                chainId: chainId,
                queue: nil,
                closure: nil
            )
        case .evm, .evmNative:
            break
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

extension AssetsUpdatingService: AssetsUpdatingServiceProtocol {
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

extension AssetsUpdatingService: EventVisitorProtocol {
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
