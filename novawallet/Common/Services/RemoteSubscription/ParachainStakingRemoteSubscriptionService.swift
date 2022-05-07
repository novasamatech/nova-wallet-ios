import Foundation
import SubstrateSdk

extension ParachainStaking {
    final class StakingRemoteSubscriptionService: RemoteSubscriptionService,
        StakingRemoteSubscriptionServiceProtocol {
        private static let globalDataStoragePaths: [StorageCodingPath] = [
            ParachainStaking.roundPath,
            ParachainStaking.totalPath,
            ParachainStaking.collatorCommissionPath,
            StorageCodingPath.totalIssuance,
            ParachainStaking.inflationConfigPath,
            ParachainStaking.parachainBondInfoPath,
            ParachainStaking.stakedPath
        ]

        private static func globalDataParamsCacheKey(for chainId: ChainModel.Id) throws -> String {
            let storageKeyFactory = StorageKeyFactory()
            let cacheKeyData = try globalDataStoragePaths.reduce(Data()) { result, storagePath in
                let storageKeyData = try storageKeyFactory.createStorageKey(
                    moduleName: storagePath.moduleName,
                    storageName: storagePath.itemName
                )

                return result + storageKeyData
            }

            return try LocalStorageKeyFactory().createKey(from: cacheKeyData, chainId: chainId)
        }

        func attachToGlobalData(
            for chainId: ChainModel.Id,
            queue: DispatchQueue?,
            closure: RemoteSubscriptionClosure?
        ) -> UUID? {
            do {
                let localKeyFactory = LocalStorageKeyFactory()

                let localKeys = try Self.globalDataStoragePaths.map { storagePath in
                    try localKeyFactory.createFromStoragePath(
                        storagePath,
                        chainId: chainId
                    )
                }

                let cacheKey = try Self.globalDataParamsCacheKey(for: chainId)

                let requests = zip(Self.globalDataStoragePaths, localKeys).map {
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
                let cacheKey = try Self.globalDataParamsCacheKey(for: chainId)

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
