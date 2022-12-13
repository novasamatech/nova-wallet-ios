import Foundation
import RobinHood
import SubstrateSdk

final class ParaStkAccountSubscribeHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
    }

    func createHandler(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> StorageChildSubscribing {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        return ParaStkScheduledRequestsUpdater(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            chainRegistry: chainRegistry,
            delegatorStorage: storage,
            accountId: accountId,
            chainId: chainId,
            operationManager: operationManager,
            storageRequestFactory: storageRequestFactory,
            logger: logger
        )
    }
}
