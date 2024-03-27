import Foundation

extension BaseParaStakingRewardCalculatoService {
    func updateTotalStaked() throws {
        totalStakedService?.throttle()
        totalStakedService = nil

        let storagePath = ParachainStaking.totalPath

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainId: chainId
        )

        let repository = repositoryFactory.createChainStorageItemRepository()

        let request = UnkeyedSubscriptionRequest(storagePath: storagePath, localKey: localKey)

        totalStakedService = StorageItemSyncService(
            chainId: chainId,
            storagePath: storagePath,
            request: request,
            repository: repository,
            connection: connection,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            logger: logger,
            completionQueue: syncQueue
        ) { [weak self] totalStaked in
            if let totalStaked = totalStaked?.value {
                self?.didUpdateTotalStaked(totalStaked)
            }
        }

        totalStakedService?.setup()
    }
}
