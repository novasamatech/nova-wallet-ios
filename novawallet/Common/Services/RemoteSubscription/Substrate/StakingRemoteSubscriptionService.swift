import Foundation
import SubstrateSdk

protocol StakingRemoteSubscriptionServiceProtocol {
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

final class StakingRemoteSubscriptionService: RemoteSubscriptionService,
    StakingRemoteSubscriptionServiceProtocol {
    private static var globalDataStoragePaths: [StorageCodingPath] {
        [
            .activeEra,
            .currentEra,
            .totalIssuance,
            .minNominatorBond,
            .maxNominatorsCount,
            .counterForNominators
        ]
    }

    private static func createBagsListRequests(
        for localKeyFactory: LocalStorageKeyFactoryProtocol,
        chainId: ChainModel.Id
    ) throws -> [UnkeyedSubscriptionRequest] {
        // we may have different modules in different chain but only on subscription will be established
        let bagListSizeRequests = try BagList.possibleModuleNames.map { moduleName in
            let storagePath = BagList.bagListSizePath(for: moduleName)
            let localKey = try localKeyFactory.createFromStoragePath(
                BagList.defaultBagListSizePath,
                chainId: chainId
            )

            return UnkeyedSubscriptionRequest(storagePath: storagePath, localKey: localKey)
        }

        return bagListSizeRequests
    }

    private static func createDataParamsCacheKey(
        for chainId: ChainModel.Id,
        paths: [StorageCodingPath]
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

            let bagListRequests = try Self.createBagsListRequests(for: localKeyFactory, chainId: chainId)

            let bagListPaths = bagListRequests.map(\.storagePath)
            let cacheKey = try Self.createDataParamsCacheKey(for: chainId, paths: globalPaths + bagListPaths)

            let globalRequests = zip(globalPaths, globalLocalKeys).map {
                UnkeyedSubscriptionRequest(storagePath: $0.0, localKey: $0.1)
            }

            let requests = globalRequests + bagListRequests

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
            let bagListRequests = try Self.createBagsListRequests(for: LocalStorageKeyFactory(), chainId: chainId)
            let bagListPaths = bagListRequests.map(\.storagePath)

            let cacheKey = try Self.createDataParamsCacheKey(
                for: chainId,
                paths: Self.globalDataStoragePaths + bagListPaths
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
