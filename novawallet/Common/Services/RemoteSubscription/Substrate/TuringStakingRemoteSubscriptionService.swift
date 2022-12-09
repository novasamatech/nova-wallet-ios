import Foundation
import SubstrateSdk

protocol TuringStakingRemoteSubscriptionProtocol {
    func attachToRewardParameters(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromRewardParameters(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

final class TuringStakingRemoteSubscriptionService: RemoteSubscriptionService,
    TuringStakingRemoteSubscriptionProtocol {
    private static let storagePaths: [StorageCodingPath] = [
        TuringStaking.totalUnvestedPath
    ]

    private static func createParamsCacheKey(for chainId: ChainModel.Id) throws -> String {
        let storageKeyFactory = StorageKeyFactory()
        let cacheKeyData = try storagePaths.reduce(Data()) { result, storagePath in
            let storageKeyData = try storageKeyFactory.createStorageKey(
                moduleName: storagePath.moduleName,
                storageName: storagePath.itemName
            )

            return result + storageKeyData
        }

        return try LocalStorageKeyFactory().createKey(from: cacheKeyData, chainId: chainId)
    }

    func attachToRewardParameters(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let localKeyFactory = LocalStorageKeyFactory()

            let localKeys = try Self.storagePaths.map { storagePath in
                try localKeyFactory.createFromStoragePath(
                    storagePath,
                    chainId: chainId
                )
            }

            let cacheKey = try Self.createParamsCacheKey(for: chainId)

            let requests = zip(Self.storagePaths, localKeys).map {
                UnkeyedSubscriptionRequest(storagePath: $0.0, localKey: $0.1)
            }

            return attachToSubscription(
                with: requests,
                chainId: chainId,
                cacheKey: cacheKey,
                queue: queue,
                closure: closure
            )
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            return nil
        }
    }

    func detachFromRewardParameters(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let cacheKey = try Self.createParamsCacheKey(for: chainId)

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
