import Foundation
import SubstrateSdk

struct NPoolSubscriptionServiceParams {
    let chainId: ChainModel.Id
    let poolId: NominationPools.PoolId
    let accountId: AccountId

    func encodableSubscriptionElement() -> [UInt8] {
        accountId.bytes + poolId.bigEndianBytes
    }
}

protocol NominationPoolsPoolSubscriptionServiceProtocol {
    func attachToAccountPoolData(
        for params: NPoolSubscriptionServiceParams,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromAccountPoolData(
        for subscriptionId: UUID,
        params: NPoolSubscriptionServiceParams,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

final class NominationPoolsPoolSubscriptionService: RemoteSubscriptionService {
    private static let poolIdStoragePaths: [StorageCodingPath] = [
        NominationPools.metadataPath,
        NominationPools.rewardPoolsPath,
        NominationPools.subPoolsPath
    ]

    private static let accountStoragePaths: [StorageCodingPath] = [
        DelegatedStakingPallet.delegatorsPath
    ]
}

extension NominationPoolsPoolSubscriptionService: NominationPoolsPoolSubscriptionServiceProtocol {
    func attachToAccountPoolData(
        for params: NPoolSubscriptionServiceParams,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let localKeyFactory = LocalStorageKeyFactory()

            let poolIdRequests: [SubscriptionRequestProtocol] = try Self.poolIdStoragePaths
                .map { path in
                    let localKey = try localKeyFactory.createFromStoragePath(
                        path,
                        encodableElement: params.poolId,
                        chainId: params.chainId
                    )

                    return MapSubscriptionRequest(storagePath: path, localKey: localKey) {
                        StringScaleMapper(value: params.poolId)
                    }
                }

            let accountRequests: [SubscriptionRequestProtocol] = try Self.accountStoragePaths.map { path in
                let localKey = try localKeyFactory.createFromStoragePath(
                    path,
                    accountId: params.accountId,
                    chainId: params.chainId
                )

                return MapSubscriptionRequest(storagePath: path, localKey: localKey) {
                    BytesCodable(wrappedValue: params.accountId)
                }
            }

            let allPaths = Self.poolIdStoragePaths + Self.accountStoragePaths

            let cacheKey = try localKeyFactory.createRestorableCacheKey(
                from: allPaths,
                encodableElement: params.encodableSubscriptionElement(),
                chainId: params.chainId
            )

            let allRequests = poolIdRequests + accountRequests

            return attachToSubscription(
                with: allRequests,
                chainId: params.chainId,
                cacheKey: cacheKey,
                queue: queue,
                closure: closure
            )

        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            return nil
        }
    }

    func detachFromAccountPoolData(
        for subscriptionId: UUID,
        params: NPoolSubscriptionServiceParams,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let allPaths = Self.poolIdStoragePaths

            let cacheKey = try LocalStorageKeyFactory().createRestorableCacheKey(
                from: allPaths,
                encodableElement: params.encodableSubscriptionElement(),
                chainId: params.chainId
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
