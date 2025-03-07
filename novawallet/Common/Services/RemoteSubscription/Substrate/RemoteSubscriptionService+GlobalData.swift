import Foundation
import SubstrateSdk

extension RemoteSubscriptionService {
    private static func globalDataParamsCacheKey(
        for paths: [StorageCodingPath],
        chainId: ChainModel.Id
    ) throws -> String {
        let storageKeyFactory = StorageKeyFactory()
        let cacheKeyData = try paths.reduce(Data()) { result, storagePath in
            let storageKeyData = try storageKeyFactory.createStorageKey(
                moduleName: storagePath.moduleName,
                storageName: storagePath.itemName
            )

            return result + storageKeyData
        }

        return try LocalStorageKeyFactory().createKey(from: cacheKeyData, chainId: chainId)
    }

    func attachToGlobalDataWithStoragePaths(
        _ paths: [StorageCodingPath],
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        subscriptionHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol?
    ) -> UUID? {
        do {
            let localKeyFactory = LocalStorageKeyFactory()

            let localKeys = try paths.map { storagePath in
                try localKeyFactory.createFromStoragePath(
                    storagePath,
                    chainId: chainId
                )
            }

            let cacheKey = try Self.globalDataParamsCacheKey(for: paths, chainId: chainId)

            let requests = zip(paths, localKeys).map {
                UnkeyedSubscriptionRequest(storagePath: $0.0, localKey: $0.1)
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

    func detachFromGlobalDataStoragePaths(
        _ paths: [StorageCodingPath],
        subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let cacheKey = try Self.globalDataParamsCacheKey(for: paths, chainId: chainId)

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
