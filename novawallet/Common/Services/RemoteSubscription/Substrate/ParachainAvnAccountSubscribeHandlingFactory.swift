import Foundation
import Operation_iOS
import SubstrateSdk

final class ParachainAvnAccountSubscribeHandlingFactory: RemoteSubscriptionHandlingFactoryProtocol {
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
        let queryWrapperFactory = ParachainAvnScheduledRequestsQueryWrapperFactory(
            storageRequestFactory: storageRequestFactory,
            operationManager: operationManager
        )

        return ParachainAvnScheduledRequestsUpdater(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            chainRegistry: chainRegistry,
            delegatorStorage: storage,
            accountId: accountId,
            chainId: chainId,
            operationManager: operationManager,
            queryWrapperFactory: queryWrapperFactory,
            logger: logger
        )
    }
}
