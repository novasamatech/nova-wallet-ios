import Foundation
import SubstrateSdk
import Operation_iOS

protocol BalanceRemoteSubscriptionServiceProtocol {
    func attachToBalances(
        for accountId: AccountId,
        chain: ChainModel,
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

    func attachToAssetBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromAssetBalance(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainAssetId: ChainAssetId,
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
    let transactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainStorageItem>,
        subscriptionHandlingFactory: BalanceRemoteSubscriptionHandlingFactoryProtocol,
        transactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol,
        syncOperationManager: OperationManagerProtocol,
        repositoryOperationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.subscriptionHandlingFactory = subscriptionHandlingFactory
        self.transactionSubscriptionFactory = transactionSubscriptionFactory

        super.init(
            chainRegistry: chainRegistry,
            repository: repository,
            syncOperationManager: syncOperationManager,
            repositoryOperationManager: repositoryOperationManager,
            logger: logger
        )
    }

    func prepareSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscribing?
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
                case .evmAsset, .evmNative, .equilibrium, .ormlHydrationEvm:
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

    func prepareSubscriptionRequests(
        from accountId: AccountId,
        chain: ChainModel,
        onlyFor assetIds: Set<AssetModel.Id>?,
        transactionSubscription: TransactionSubscribing?
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

private extension BalanceRemoteSubscriptionService {
    func getAccountInfoRequest(
        from accountId: AccountId,
        chainId: ChainModel.Id,
        storageKeyFactory: LocalStorageKeyFactoryProtocol
    ) throws -> MapSubscriptionRequest<BytesCodable> {
        let accountStoragePath = SystemPallet.accountPath
        let accountLocalKey = try storageKeyFactory.createFromStoragePath(
            accountStoragePath,
            accountId: accountId,
            chainId: chainId
        )

        return MapSubscriptionRequest(storagePath: accountStoragePath, localKey: accountLocalKey) {
            BytesCodable(wrappedValue: accountId)
        }
    }

    func getLocksRequest(
        from accountId: AccountId,
        chainId: ChainModel.Id,
        storageKeyFactory: LocalStorageKeyFactoryProtocol
    ) throws -> MapSubscriptionRequest<BytesCodable> {
        let locksStoragePath = StorageCodingPath.balanceLocks
        let locksLocalKey = try storageKeyFactory.createFromStoragePath(
            locksStoragePath,
            encodableElement: accountId,
            chainId: chainId
        )

        return MapSubscriptionRequest(
            storagePath: locksStoragePath,
            localKey: locksLocalKey
        ) { BytesCodable(wrappedValue: accountId) }
    }

    func getHoldsRequest(
        from accountId: AccountId,
        chainId: ChainModel.Id,
        storageKeyFactory: LocalStorageKeyFactoryProtocol
    ) throws -> MapSubscriptionRequest<BytesCodable> {
        let holdsStoragePath = BalancesPallet.holdsPath
        let holdsLocalKey = try storageKeyFactory.createFromStoragePath(
            holdsStoragePath,
            encodableElement: accountId,
            chainId: chainId
        )

        return MapSubscriptionRequest(
            storagePath: holdsStoragePath,
            localKey: holdsLocalKey
        ) { BytesCodable(wrappedValue: accountId) }
    }

    func getFreezesRequest(
        from accountId: AccountId,
        chainId: ChainModel.Id,
        storageKeyFactory: LocalStorageKeyFactoryProtocol
    ) throws -> MapSubscriptionRequest<BytesCodable> {
        let freezesStoragePath = BalancesPallet.freezesPath
        let freezesLocalKey = try storageKeyFactory.createFromStoragePath(
            freezesStoragePath,
            encodableElement: accountId,
            chainId: chainId
        )

        return MapSubscriptionRequest(
            storagePath: freezesStoragePath,
            localKey: freezesLocalKey
        ) { BytesCodable(wrappedValue: accountId) }
    }

    func prepareNativeAssetSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscribing?
    ) throws -> [SubscriptionSettings] {
        let storageKeyFactory = LocalStorageKeyFactory()
        let chainId = chainAsset.chain.chainId

        let accountRequest = try getAccountInfoRequest(
            from: accountId,
            chainId: chainId,
            storageKeyFactory: storageKeyFactory
        )

        let locksRequest = try getLocksRequest(
            from: accountId,
            chainId: chainId,
            storageKeyFactory: storageKeyFactory
        )

        let holdsRequest = try getHoldsRequest(
            from: accountId,
            chainId: chainId,
            storageKeyFactory: storageKeyFactory
        )

        let freezesRequest = try getFreezesRequest(
            from: accountId,
            chainId: chainId,
            storageKeyFactory: storageKeyFactory
        )

        let handlerFactory = subscriptionHandlingFactory.createNative(
            for: accountId,
            chainAssetId: chainAsset.chainAssetId,
            params: .init(
                accountLocalStorageKey: accountRequest.localKey,
                locksLocalStorageKey: locksRequest.localKey,
                holdsLocalStorageKey: holdsRequest.localKey,
                freezesLocalStorageKey: freezesRequest.localKey
            ),
            transactionSubscription: transactionSubscription
        )

        return [
            SubscriptionSettings(request: accountRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: locksRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: holdsRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: freezesRequest, handlingFactory: handlerFactory)
        ]
    }

    func prepareAssetsPalletSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscribing?
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
            params: .init(assetAccountKey: accountLocalKey, assetDetailsKey: detailsLocalKey, extras: extras),
            transactionSubscription: transactionSubscription
        )

        return [
            SubscriptionSettings(request: accountRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: detailsRequest, handlingFactory: handlerFactory)
        ]
    }

    func prepareOrmlSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscribing?
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
            params: .init(accountLocalStorageKey: accountLocalKey, locksLocalStorageKey: locksLocalKey),
            transactionSubscription: transactionSubscription
        )

        return [
            SubscriptionSettings(request: accountRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: locksRequest, handlingFactory: handlerFactory)
        ]
    }
}
