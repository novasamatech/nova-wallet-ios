import Foundation
import SubstrateSdk

protocol NominationPoolsPoolSubscriptionServiceProtocol {
    func attachToPoolData(
        for chainId: ChainModel.Id,
        poolId: NominationPools.PoolId,
        palletId: Data,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromPoolData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        poolId: NominationPools.PoolId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

final class NominationPoolsPoolSubscriptionService: RemoteSubscriptionService {
    private static let poolIdStoragePaths: [StorageCodingPath] = [
        NominationPools.bondedPoolPath,
        NominationPools.metadataPath,
        NominationPools.rewardPoolsPath,
        NominationPools.subPoolsPath
    ]

    private static let poolAccountStoragePaths: [StorageCodingPath] = [
        .stakingLedger,
        .nominators
    ]
}

extension NominationPoolsPoolSubscriptionService {
    func attachToPoolData(
        for chainId: ChainModel.Id,
        poolId: NominationPools.PoolId,
        palletId: Data,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let poolAccountId = try NominationPools.derivedAccount(
                for: poolId,
                accountType: .bonded,
                palletId: palletId
            )

            let localKeyFactory = LocalStorageKeyFactory()

            let poolIdRequests: [SubscriptionRequestProtocol] = try Self.poolIdStoragePaths
                .map { path in
                    let localKey = try localKeyFactory.createFromStoragePath(
                        path,
                        encodableElement: poolId,
                        chainId: chainId
                    )

                    return MapSubscriptionRequest(storagePath: path, localKey: localKey) {
                        StringScaleMapper(value: poolId)
                    }
                }

            let poolAccountRequests: [SubscriptionRequestProtocol] = try Self.poolAccountStoragePaths
                .map { path in
                    let localKey = try localKeyFactory.createFromStoragePath(
                        path,
                        accountId: poolAccountId,
                        chainId: chainId
                    )

                    return MapSubscriptionRequest(
                        storagePath: path,
                        localKey: localKey,
                        keyParamClosure: { BytesCodable(wrappedValue: poolAccountId) }
                    )
                }

            let allPaths = Self.poolIdStoragePaths + Self.poolAccountStoragePaths

            let cacheKey = try localKeyFactory.createRestorableCacheKey(
                from: allPaths,
                encodableElement: poolId,
                chainId: chainId
            )

            let allRequests = poolIdRequests + poolAccountRequests

            return attachToSubscription(
                with: allRequests,
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

    func detachFromPoolData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        poolId: NominationPools.PoolId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let allPaths = Self.poolIdStoragePaths + Self.poolAccountStoragePaths

            let cacheKey = try LocalStorageKeyFactory().createRestorableCacheKey(
                from: allPaths,
                encodableElement: poolId,
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
