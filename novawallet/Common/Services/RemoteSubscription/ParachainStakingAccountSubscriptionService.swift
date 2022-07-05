import Foundation
import SubstrateSdk
import RobinHood

protocol ParachainStakingAccountSubscriptionServiceProtocol {
    func attachToAccountData(
        for chainId: ChainModel.Id,
        accountId: AccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromAccountData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        accountId: AccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

extension ParachainStaking {
    final class AccountSubscriptionService: RemoteSubscriptionService,
        ParachainStakingAccountSubscriptionServiceProtocol {
        private static let storagePaths: [StorageCodingPath] = [
            ParachainStaking.delegatorStatePath
        ]

        private static func createCacheKey(
            for chainId: ChainModel.Id,
            accountId: AccountId
        ) throws -> String {
            let storageKeyFactory = StorageKeyFactory()
            let cacheKeyData = try storagePaths.reduce(Data()) { result, storagePath in
                let storageKeyData = try storageKeyFactory.createStorageKey(
                    moduleName: storagePath.moduleName,
                    storageName: storagePath.itemName
                )

                return result + storageKeyData
            }

            return try LocalStorageKeyFactory().createRestorableKey(
                from: cacheKeyData + accountId,
                chainId: chainId
            )
        }

        func attachToAccountData(
            for chainId: ChainModel.Id,
            accountId: AccountId,
            queue: DispatchQueue?,
            closure: RemoteSubscriptionClosure?
        ) -> UUID? {
            do {
                let localKeyFactory = LocalStorageKeyFactory()

                let requests: [SubscriptionRequestProtocol] = try Self.storagePaths
                    .map { path in
                        let localKey = try localKeyFactory.createFromStoragePath(
                            path,
                            accountId: accountId,
                            chainId: chainId
                        )

                        return MapSubscriptionRequest(
                            storagePath: path,
                            localKey: localKey,
                            keyParamClosure: { accountId }
                        )
                    }

                let cacheKey = try Self.createCacheKey(
                    for: chainId,
                    accountId: accountId
                )

                let subscriptionHandlingFactory = ParaStkAccountSubscribeHandlingFactory(
                    chainId: chainId,
                    accountId: accountId,
                    chainRegistry: chainRegistry
                )

                return attachToSubscription(
                    with: requests,
                    chainId: chainId,
                    cacheKey: cacheKey,
                    queue: queue,
                    closure: closure,
                    subscriptionHandlingFactory: subscriptionHandlingFactory
                )

            } catch {
                callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
                return nil
            }
        }

        func detachFromAccountData(
            for subscriptionId: UUID,
            chainId: ChainModel.Id,
            accountId: AccountId,
            queue: DispatchQueue?,
            closure: RemoteSubscriptionClosure?
        ) {
            do {
                let cacheKey = try Self.createCacheKey(for: chainId, accountId: accountId)

                detachFromSubscription(
                    cacheKey,
                    subscriptionId: subscriptionId,
                    queue: queue,
                    closure: closure
                )
            } catch {
                callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            }
        }
    }
}
