import Foundation
import SubstrateSdk
import Operation_iOS

protocol BalanceRemoteSubscriptionServiceProtocol {
    func attachToBalances(
        for accountId: AccountId,
        chain: ChainModel,
        transactionSubscription: TransactionSubscription?,
        onlyFor assetIds: Set<AssetModel.Id>?,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromBalances(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

final class BalanceRemoteSubscriptionService: RemoteSubscriptionService {
    struct SubscriptionSettings {
        let request: SubscriptionRequestProtocol
        let handlingFactory: RemoteSubscriptionHandlingFactoryProtocol
    }

    let subscriptionHandlingFactory: BalanceRemoteSubscriptionHandlingFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainStorageItem>,
        subscriptionHandlingFactory: BalanceRemoteSubscriptionHandlingFactoryProtocol,
        syncOperationManager: OperationManagerProtocol,
        repositoryOperationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.subscriptionHandlingFactory = subscriptionHandlingFactory

        super.init(
            chainRegistry: chainRegistry,
            repository: repository,
            syncOperationManager: syncOperationManager,
            repositoryOperationManager: repositoryOperationManager,
            logger: logger
        )
    }

    private func createCacheKey(from accountId: AccountId, chainId: ChainModel.Id) -> String {
        "balances-\(accountId.toHex())-\(chainId)"
    }

    private func prepareNativeAssetSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscription?
    ) throws -> [SubscriptionSettings] {
        let storagePath = StorageCodingPath.account
        let storageKeyFactory = LocalStorageKeyFactory()
        let chainId = chainAsset.chain.chainId

        let accountLocalKey = try storageKeyFactory.createFromStoragePath(
            storagePath,
            accountId: accountId,
            chainId: chainId
        )

        let locksStoragePath = StorageCodingPath.balanceLocks
        let locksLocalKey = try storageKeyFactory.createFromStoragePath(
            locksStoragePath,
            encodableElement: accountId,
            chainId: chainId
        )

        let accountRequest = MapSubscriptionRequest(
            storagePath: storagePath,
            localKey: accountLocalKey
        ) { BytesCodable(wrappedValue: accountId) }

        let locksRequest = MapSubscriptionRequest(
            storagePath: .balanceLocks,
            localKey: locksLocalKey
        ) { BytesCodable(wrappedValue: accountId) }

        let handlerFactory = subscriptionHandlingFactory.createNative(
            for: accountId,
            chainAssetId: chainAsset.chainAssetId,
            accountLocalStorageKey: accountLocalKey,
            locksLocalStorageKey: locksLocalKey,
            transactionSubscription: transactionSubscription
        )

        return [
            SubscriptionSettings(request: accountRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: locksRequest, handlingFactory: handlerFactory)
        ]
    }

    private func prepareAssetsPalletSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscription?
    ) throws -> [SubscriptionSettings] {
        guard let extras = try chainAsset.asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
            return []
        }

        let chainId = chainAsset.chain.chainId

        let localKeyFactory = LocalStorageKeyFactory()

        let assetId = extras.assetId
        let accountStoragePath = StorageCodingPath.assetsAccount(from: extras.palletName)
        let accountLocalKey = try localKeyFactory.createFromStoragePath(
            accountStoragePath,
            encodableElements: [assetId, accountId],
            chainId: chainId
        )

        let accountRequest = DoubleMapSubscriptionRequest(
            storagePath: accountStoragePath,
            localKey: accountLocalKey,
            keyParamClosure: { (assetId, accountId) },
            param1Encoder: StatemineAssetSerializer.subscriptionKeyEncoder(for: assetId),
            param2Encoder: nil
        )

        let detailsStoragePath = StorageCodingPath.assetsDetails(from: extras.palletName)
        let detailsLocalKey = try localKeyFactory.createFromStoragePath(
            detailsStoragePath,
            encodableElement: assetId,
            chainId: chainId
        )

        let detailsRequest = MapSubscriptionRequest(
            storagePath: detailsStoragePath,
            localKey: detailsLocalKey,
            keyParamClosure: { assetId },
            paramEncoder: StatemineAssetSerializer.subscriptionKeyEncoder(for: assetId)
        )

        let handlerFactory = subscriptionHandlingFactory.createAssetsPallet(
            for: accountId,
            chainAssetId: chainAsset.chainAssetId,
            extras: extras,
            assetAccountKey: accountLocalKey,
            assetDetailsKey: detailsLocalKey,
            transactionSubscription: transactionSubscription
        )

        return [
            SubscriptionSettings(request: accountRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: detailsRequest, handlingFactory: handlerFactory)
        ]
    }

    private func prepareOrmlSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscription?
    ) throws -> [SubscriptionSettings] {
        guard let tokenExtras = try chainAsset.asset.typeExtras?.map(to: OrmlTokenExtras.self) else {
            return []
        }

        let currencyId = try Data(hexString: tokenExtras.currencyIdScale)
        let chainId = chainAsset.chain.chainId

        let storageKeyFactory = LocalStorageKeyFactory()
        let accountLocalKey = try storageKeyFactory.createFromStoragePath(
            .ormlTokenAccount,
            encodableElement: accountId + currencyId,
            chainId: chainId
        )

        let accountRequest = DoubleMapSubscriptionRequest(
            storagePath: .ormlTokenAccount,
            localKey: accountLocalKey,
            keyParamClosure: { (accountId, currencyId) },
            param1Encoder: nil,
            param2Encoder: { $0 }
        )

        let locksLocalKey = try storageKeyFactory.createFromStoragePath(
            .ormlTokenLocks,
            encodableElement: accountId + currencyId,
            chainId: chainId
        )

        let locksRequest = DoubleMapSubscriptionRequest(
            storagePath: .ormlTokenLocks,
            localKey: locksLocalKey,
            keyParamClosure: { (accountId, currencyId) },
            param1Encoder: nil,
            param2Encoder: { $0 }
        )

        let handlerFactory = subscriptionHandlingFactory.createOrml(
            for: accountId,
            chainAssetId: chainAsset.chainAssetId,
            accountLocalStorageKey: accountLocalKey,
            locksLocalStorageKey: locksLocalKey,
            transactionSubscription: transactionSubscription
        )

        return [
            SubscriptionSettings(request: accountRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: locksRequest, handlingFactory: handlerFactory)
        ]
    }

    private func prepareSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscription?
    ) -> [SubscriptionSettings] {
        do {
            if let assetRawType = chainAsset.asset.type {
                guard let customAssetType = AssetType(rawValue: assetRawType) else {
                    return []
                }

                switch customAssetType {
                case .statemine:
                    return try prepareAssetsPalletSubscriptionRequests(
                        from: accountId,
                        chainAsset: chainAsset,
                        transactionSubscription: transactionSubscription
                    )
                case .orml:
                    return try prepareOrmlSubscriptionRequests(
                        from: accountId,
                        chainAsset: chainAsset,
                        transactionSubscription: transactionSubscription
                    )
                case .evmAsset, .evmNative, .equilibrium:
                    logger.error("Unsupported asset type: \(customAssetType)")
                    return []
                }
            } else {
                return try prepareNativeAssetSubscriptionRequests(
                    from: accountId,
                    chainAsset: chainAsset,
                    transactionSubscription: transactionSubscription
                )
            }
        } catch {
            logger.error("Can't create request: \(error)")
            return []
        }
    }

    private func prepareSubscriptionRequests(
        from accountId: AccountId,
        chain: ChainModel,
        onlyFor assetIds: Set<AssetModel.Id>?,
        transactionSubscription: TransactionSubscription?
    ) -> [SubscriptionSettings] {
        let chainAssets = if let assetIds {
            chain.chainAssets().filter { assetIds.contains($0.asset.assetId) }
        } else {
            chain.chainAssets()
        }

        return chainAssets.flatMap { chainAsset in
            prepareSubscriptionRequests(
                from: accountId,
                chainAsset: chainAsset,
                transactionSubscription: transactionSubscription
            )
        }
    }
}

extension BalanceRemoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol {
    func attachToBalances(
        for accountId: AccountId,
        chain: ChainModel,
        transactionSubscription: TransactionSubscription?,
        onlyFor assetIds: Set<AssetModel.Id>?,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        let subscriptionSettingsList = prepareSubscriptionRequests(
            from: accountId,
            chain: chain,
            onlyFor: assetIds,
            transactionSubscription: transactionSubscription
        )

        guard !subscriptionSettingsList.isEmpty else {
            return nil
        }

        let cacheKey = createCacheKey(from: accountId, chainId: chain.chainId)

        let requests = subscriptionSettingsList.map(\.request)
        let handlersStore = subscriptionSettingsList.reduce(
            into: [String: RemoteSubscriptionHandlingFactoryProtocol]()
        ) { accum, settings in
            accum[settings.request.localKey] = settings.handlingFactory
        }

        let handlingFactory = BalanceRemoteSubscriptionHandlingProxy(store: handlersStore)

        return attachToSubscription(
            with: requests,
            chainId: chain.chainId,
            cacheKey: cacheKey,
            queue: queue,
            closure: closure,
            subscriptionHandlingFactory: handlingFactory
        )
    }

    func detachFromBalances(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        let cacheKey = createCacheKey(from: accountId, chainId: chainId)
        detachFromSubscription(cacheKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
    }
}
