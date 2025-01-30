import Foundation
import SubstrateSdk

extension RemoteSubscriptionService {
    private static func accountDataDataParamsCacheKey(
        for paths: [StorageCodingPath],
        chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> String {
        let storageKeyFactory = StorageKeyFactory()
        let cacheKeyData = try paths.reduce(Data()) { result, storagePath in
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

    func attachToAccountDataWithStoragePaths(
        _ paths: [StorageCodingPath],
        chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        subscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol?
    ) -> UUID? {
        do {
            let localKeyFactory = LocalStorageKeyFactory()
            let accountId = chainAccountId.accountId
            let chainId = chainAccountId.chainId

            let localKeys = try paths.map { storagePath in
                try localKeyFactory.createFromStoragePath(
                    storagePath,
                    accountId: accountId,
                    chainId: chainId
                )
            }

            let cacheKey = try Self.accountDataDataParamsCacheKey(
                for: paths,
                chainId: chainId,
                accountId: accountId
            )

            let requests = zip(paths, localKeys).map {
                MapSubscriptionRequest(
                    storagePath: $0,
                    localKey: $1
                ) {
                    BytesCodable(wrappedValue: accountId)
                }
            }

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

    func detachFromAccountDataStoragePaths(
        _ paths: [StorageCodingPath],
        subscriptionId: UUID,
        chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let cacheKey = try Self.accountDataDataParamsCacheKey(
                for: paths,
                chainId: chainAccountId.chainId,
                accountId: chainAccountId.accountId
            )

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
