import Foundation
import SubstrateSdk

protocol NominationPoolsRemoteSubscriptionServiceProtocol {
    func attachToGlobalData(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromGlobalData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

final class NominationPoolsRemoteSubscriptionService: RemoteSubscriptionService {
    private static var globalDataStoragePaths: [StorageCodingPath] {
        [
            NominationPools.lastPoolIdPath,
            NominationPools.minJoinBondPath,
            NominationPools.maxPoolMembers,
            NominationPools.counterForPoolMembers,
            NominationPools.maxMembersPerPool
        ]
    }
}

extension NominationPoolsRemoteSubscriptionService: NominationPoolsRemoteSubscriptionServiceProtocol {
    func attachToGlobalData(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let localKeyFactory = LocalStorageKeyFactory()

            let globalPaths = Self.globalDataStoragePaths
            let globalLocalKeys = try globalPaths.map { storagePath in
                try localKeyFactory.createFromStoragePath(
                    storagePath,
                    chainId: chainId
                )
            }

            let cacheKey = try localKeyFactory.createCacheKey(from: globalPaths, chainId: chainId)

            let requests = zip(globalPaths, globalLocalKeys).map {
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

    func detachFromGlobalData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let cacheKey = try LocalStorageKeyFactory().createCacheKey(
                from: Self.globalDataStoragePaths,
                chainId: chainId
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
