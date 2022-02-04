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

    private func createSubscription(
        for asset: AssetModel,
        accountId: AccountId,
        chain: ChainModel
    ) -> SubscriptionInfo? {
        guard let typeString = asset.type, let assetType = AssetType(rawValue: typeString) else {
            return nil
        }

        let transactionSubscription = try? createTransactionSubscription(for: accountId, chain: chain)

        switch assetType {
        case .statemine:
            return createStatemineSubscription(
                for: asset,
                accountId: accountId,
                chainId: chain.chainId,
                transactionSubscription: transactionSubscription
            )
        case .orml:
            return createOrmlTokenSubscription(
                for: asset,
                accountId: accountId,
                chainId: chain.chainId,
                transactionSubscription: transactionSubscription
            )
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
        let chainItemRepository = repositoryFactory.createChainStorageItemRepository()

        let assetBalanceUpdater = AssetsBalanceUpdater(
            chainAssetId: ChainAssetId(chainId: chainId, assetId: asset.assetId),
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: assetRepository,
            chainRepository: chainItemRepository,
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        let maybeSubscriptionId = remoteSubscriptionService.attachToAsset(
            of: accountId,
            assetId: assetExtras.assetId,
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

        let assetsRepository = repositoryFactory.createAssetBalanceRepository()
        let subscriptionHandlingFactory = OrmlAccountSubscriptionHandlingFactory(
            chainAssetId: ChainAssetId(chainId: chainId, assetId: asset.assetId),
            accountId: accountId,
            chainRegistry: chainRegistry,
            assetRepository: assetsRepository,
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
