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

    private func prepareNativeAssetSubscriptionRequests(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        transactionSubscription: TransactionSubscribing?
    ) throws -> [SubscriptionSettings] {
        let storageKeyFactory = LocalStorageKeyFactory()
        let chainId = chainAsset.chain.chainId

        let accountStoragePath = SystemPallet.accountPath
        let accountLocalKey = try storageKeyFactory.createFromStoragePath(
            accountStoragePath,
            accountId: accountId,
            chainId: chainId
        )

        let locksStoragePath = StorageCodingPath.balanceLocks
        let locksLocalKey = try storageKeyFactory.createFromStoragePath(
            locksStoragePath,
            encodableElement: accountId,
            chainId: chainId
        )

        let holdsStoragePath = BalancesPallet.holdsPath
        let holdsLocalKey = try storageKeyFactory.createFromStoragePath(
            holdsStoragePath,
            encodableElement: accountId,
            chainId: chainId
        )

        let accountRequest = MapSubscriptionRequest(storagePath: accountStoragePath, localKey: accountLocalKey) {
            BytesCodable(wrappedValue: accountId)
        }

        let locksRequest = MapSubscriptionRequest(
            storagePath: locksStoragePath,
            localKey: locksLocalKey
        ) { BytesCodable(wrappedValue: accountId) }

        let holdsRequest = MapSubscriptionRequest(
            storagePath: holdsStoragePath,
            localKey: holdsLocalKey
        ) { BytesCodable(wrappedValue: accountId) }

        let handlerFactory = subscriptionHandlingFactory.createNative(
            for: accountId,
            chainAssetId: chainAsset.chainAssetId,
            params: .init(
                accountLocalStorageKey: accountLocalKey,
                locksLocalStorageKey: locksLocalKey,
                holdsLocalStorageKey: holdsLocalKey
            ),
            transactionSubscription: transactionSubscription
        )

        return [
            SubscriptionSettings(request: accountRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: locksRequest, handlingFactory: handlerFactory),
            SubscriptionSettings(request: holdsRequest, handlingFactory: handlerFactory)
        ]
    }

    private func prepareAssetsPalletSubscriptionRequests(
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

    private func prepareOrmlSubscriptionRequests(
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
