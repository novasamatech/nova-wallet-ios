import Foundation
import SubstrateSdk
import Operation_iOS

protocol EquillibriumRemoteSubscriptionServiceProtocol {
    func attachToEquilibriumAssets(
        info: RemoteEquilibriumSubscriptionInfo,
        balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol,
        locksUpdater: EquillibriumLocksUpdaterProtocol,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromEquilibriumAssets(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

class EquillibriumRemoteSubscriptionService: RemoteSubscriptionService, EquillibriumRemoteSubscriptionServiceProtocol {
    func attachToEquilibriumAssets(
        info: RemoteEquilibriumSubscriptionInfo,
        balanceUpdater: EquillibriumAssetsBalanceUpdaterProtocol,
        locksUpdater: EquillibriumLocksUpdaterProtocol,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let chainId = info.chain.chainId
            let accountId = info.accountId

            let storageKeyFactory = LocalStorageKeyFactory()
            let balancesLocalKey = try storageKeyFactory.createFromStoragePath(
                .equilibriumBalances,
                encodableElement: accountId,
                chainId: chainId
            )

            let accountKeyMapper = {
                accountId.map { StringScaleMapper(value: $0) }
            }

            let balancesRequest = MapSubscriptionRequest(
                storagePath: .equilibriumBalances,
                localKey: balancesLocalKey,
                keyParamClosure: accountKeyMapper
            )

            let locksLocalKey = try storageKeyFactory.createFromStoragePath(
                .equilibriumLocks,
                encodableElement: accountId,
                chainId: chainId
            )

            let locksRequest = MapSubscriptionRequest(
                storagePath: .equilibriumLocks,
                localKey: locksLocalKey,
                keyParamClosure: accountKeyMapper
            )

            let allReservedBalancesLocalKey = try storageKeyFactory.createFromStoragePath(
                .equilibriumReserved,
                encodableElement: accountId,
                chainId: chainId
            )

            let reservedAsssetRequests = try info.assets.reduce(
                into: [EquilibriumAssetId: SubscriptionRequestProtocol]()
            ) { result, asset in
                let key = try storageKeyFactory.createFromStoragePath(
                    .equilibriumReserved,
                    encodableElements: [asset, accountId],
                    chainId: chainId
                )
                result[asset] = DoubleMapSubscriptionRequest(
                    storagePath: .equilibriumReserved,
                    localKey: key,
                    keyParamClosure: {
                        (BytesCodable(wrappedValue: info.accountId), StringScaleMapper(value: asset))
                    },
                    param1Encoder: nil,
                    param2Encoder: nil
                )
            }

            let reservedRequests = reservedAsssetRequests.values
            let reservedKeys: [String: EquilibriumAssetId] = .init(uniqueKeysWithValues: reservedAsssetRequests.map {
                ($0.value.localKey, $0.key)
            })

            let handlingFactory = EquilibriumSubscriptionHandlingFactory(
                accountBalanceKey: balancesLocalKey,
                locksKey: locksLocalKey,
                reservedKeys: reservedKeys,
                balanceUpdater: balanceUpdater,
                locksUpdater: locksUpdater
            )

            return attachToSubscription(
                with: [balancesRequest, locksRequest] + reservedRequests,
                chainId: chainId,
                cacheKey: balancesLocalKey + locksLocalKey + allReservedBalancesLocalKey,
                queue: queue,
                closure: closure,
                subscriptionHandlingFactory: handlingFactory
            )
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            return nil
        }
    }

    func detachFromEquilibriumAssets(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let storageKeyFactory = LocalStorageKeyFactory()
            let balancesLocalKey = try storageKeyFactory.createFromStoragePath(
                .equilibriumBalances,
                encodableElement: accountId,
                chainId: chainId
            )
            let locksLocalKey = try storageKeyFactory.createFromStoragePath(
                .equilibriumLocks,
                encodableElement: accountId,
                chainId: chainId
            )
            let reservedBalanceLocalKey = try storageKeyFactory.createFromStoragePath(
                .equilibriumReserved,
                encodableElement: accountId,
                chainId: chainId
            )

            let localKey = balancesLocalKey + locksLocalKey + reservedBalanceLocalKey
            detachFromSubscription(localKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }
}
