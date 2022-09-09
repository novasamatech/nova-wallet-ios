import Foundation
import SubstrateSdk
import RobinHood

protocol WalletRemoteSubscriptionServiceProtocol {
    // swiftlint:disable:next function_parameter_count
    func attachToAccountInfo(
        of accountId: AccountId,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        subscriptionHandlingFactory: NativeTokenSubscriptionFactoryProtocol
    ) -> UUID?

    func detachFromAccountInfo(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )

    // swiftlint:disable:next function_parameter_count
    func attachToAsset(
        of accountId: AccountId,
        assetId: String,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        assetBalanceUpdater: AssetsBalanceUpdater,
        transactionSubscription: TransactionSubscription?
    ) -> UUID?

    // swiftlint:disable:next function_parameter_count
    func detachFromAsset(
        for subscriptionId: UUID,
        accountId: AccountId,
        assetId: String,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )

    // swiftlint:disable:next function_parameter_count
    func attachToOrmlToken(
        of accountId: AccountId,
        currencyId: Data,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        subscriptionHandlingFactory: OrmlTokenSubscriptionFactoryProtocol
    ) -> UUID?

    // swiftlint:disable:next function_parameter_count
    func detachFromOrmlToken(
        for subscriptionId: UUID,
        accountId: AccountId,
        currencyId: Data,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

class WalletRemoteSubscriptionService: RemoteSubscriptionService, WalletRemoteSubscriptionServiceProtocol {
    // swiftlint:disable:next function_parameter_count
    func attachToAccountInfo(
        of accountId: AccountId,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        subscriptionHandlingFactory: NativeTokenSubscriptionFactoryProtocol
    ) -> UUID? {
        do {
            let storagePath = StorageCodingPath.account
            let storageKeyFactory = LocalStorageKeyFactory()
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

            let accountRequest: SubscriptionRequestProtocol
            let locksRequest: SubscriptionRequestProtocol
            switch chainFormat {
            case .substrate:
                accountRequest = MapSubscriptionRequest(
                    storagePath: storagePath,
                    localKey: accountLocalKey
                ) { accountId }
                locksRequest = MapSubscriptionRequest(
                    storagePath: .balanceLocks,
                    localKey: locksLocalKey,
                    keyParamClosure: {
                        accountId
                    }
                )
            case .ethereum:
                accountRequest = MapSubscriptionRequest(
                    storagePath: storagePath,
                    localKey: accountLocalKey
                ) { accountId.map { StringScaleMapper(value: $0) } }

                locksRequest = MapSubscriptionRequest(
                    storagePath: .balanceLocks,
                    localKey: locksLocalKey,
                    keyParamClosure: { accountId.map { StringScaleMapper(value: $0) } }
                )
            }

            let handlingFactory = AccountInfoSubscriptionHandlingFactory(
                accountLocalStorageKey: accountLocalKey,
                locksLocalStorageKey: locksLocalKey,
                factory: subscriptionHandlingFactory
            )

            return attachToSubscription(
                with: [accountRequest, locksRequest],
                chainId: chainId,
                cacheKey: accountLocalKey + locksLocalKey,
                queue: queue,
                closure: closure,
                subscriptionHandlingFactory: handlingFactory
            )

        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            return nil
        }
    }

    func detachFromAccountInfo(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let storagePath = StorageCodingPath.account
            let storageKeyFactory = LocalStorageKeyFactory()
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

            let localKey = accountLocalKey + locksLocalKey
            detachFromSubscription(localKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }

    // swiftlint:disable:next function_parameter_count
    func attachToAsset(
        of accountId: AccountId,
        assetId: String,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        assetBalanceUpdater: AssetsBalanceUpdater,
        transactionSubscription: TransactionSubscription?
    ) -> UUID? {
        do {
            let localKeyFactory = LocalStorageKeyFactory()

            let accountStoragePath = StorageCodingPath.assetsAccount
            let accountLocalKey = try localKeyFactory.createFromStoragePath(
                accountStoragePath,
                encodableElements: [assetId, accountId],
                chainId: chainId
            )

            let accountRequest = DoubleMapSubscriptionRequest(
                storagePath: accountStoragePath,
                localKey: accountLocalKey,
                keyParamClosure: { (assetId, accountId) },
                param1Encoder: nil,
                param2Encoder: nil
            )

            let detailsStoragePath = StorageCodingPath.assetsDetails
            let detailsLocalKey = try localKeyFactory.createFromStoragePath(
                detailsStoragePath,
                encodableElement: assetId,
                chainId: chainId
            )

            let detailsRequest = MapSubscriptionRequest(
                storagePath: detailsStoragePath,
                localKey: detailsLocalKey,
                keyParamClosure: { StringScaleMapper(value: assetId) }
            )

            let handlingFactory = AssetsSubscriptionHandlingFactory(
                assetAccountKey: accountLocalKey,
                assetDetailsKey: detailsLocalKey,
                assetBalanceUpdater: assetBalanceUpdater,
                transactionSubscription: transactionSubscription
            )

            return attachToSubscription(
                with: [detailsRequest, accountRequest],
                chainId: chainId,
                cacheKey: accountLocalKey,
                queue: queue,
                closure: closure,
                subscriptionHandlingFactory: handlingFactory
            )
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))

            return nil
        }
    }

    // swiftlint:disable:next function_parameter_count
    func detachFromAsset(
        for subscriptionId: UUID,
        accountId: AccountId,
        assetId: String,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let storagePath = StorageCodingPath.assetsAccount
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                encodableElements: [assetId, accountId],
                chainId: chainId
            )

            detachFromSubscription(localKey, subscriptionId: subscriptionId, queue: queue, closure: closure)

        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }

    // swiftlint:disable:next function_parameter_count
    func attachToOrmlToken(
        of accountId: AccountId,
        currencyId: Data,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        subscriptionHandlingFactory: OrmlTokenSubscriptionFactoryProtocol
    ) -> UUID? {
        do {
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

            let handlingFactory = OrmlTokenSubscriptionHandlingFactory(
                accountLocalStorageKey: accountLocalKey,
                locksLocalStorageKey: locksLocalKey,
                factory: subscriptionHandlingFactory
            )

            return attachToSubscription(
                with: [accountRequest, locksRequest],
                chainId: chainId,
                cacheKey: accountLocalKey + locksLocalKey,
                queue: queue,
                closure: closure,
                subscriptionHandlingFactory: handlingFactory
            )

        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            return nil
        }
    }

    // swiftlint:disable:next function_parameter_count
    func detachFromOrmlToken(
        for subscriptionId: UUID,
        accountId: AccountId,
        currencyId: Data,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let storageKeyFactory = LocalStorageKeyFactory()
            let accountLocalKey = try storageKeyFactory.createFromStoragePath(
                .ormlTokenAccount,
                encodableElement: accountId + currencyId,
                chainId: chainId
            )
            let locksLocalKey = try storageKeyFactory.createFromStoragePath(
                .ormlTokenLocks,
                encodableElement: accountId + currencyId,
                chainId: chainId
            )
            let localKey = accountLocalKey + locksLocalKey

            detachFromSubscription(localKey, subscriptionId: subscriptionId, queue: queue, closure: closure)

        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }
}
