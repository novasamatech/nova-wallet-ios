import Foundation

extension ParaStakingRewardCalculatorService {
    func updateStaked(for roundInfo: ParachainStaking.RoundInfo) {
        totalStakedService?.throttle()
        totalStakedService = nil

        let storagePath = ParachainStaking.stakedPath

        guard let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            encodableElement: roundInfo.current,
            chainId: chainId
        ) else {
            logger.error("Can't encode local key")
            return
        }

        let repository = repositoryFactory.createChainStorageItemRepository()

        let request = MapSubscriptionRequest(
            storagePath: storagePath,
            localKey: localKey,
            keyParamClosure: { String(roundInfo.current) }
        )

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
