import Foundation
import Operation_iOS
import SubstrateSdk

protocol PendingMultisigChainSyncServiceFactoryProtocol {
    func createMultisigChainSyncService(
        for chain: ChainModel,
        selectedMultisigAccount: DelegatedAccount.MultisigAccountModel
    ) -> PendingMultisigChainSyncServiceProtocol
}

final class PendingMultisigChainSyncServiceFactory {
    private let chainRegistry: ChainRegistryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let operationManager: OperationManagerProtocol
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.operationQueue = operationQueue
    }
}

// MARK: - PendingMultisigChainSyncServiceFactoryProtocol

extension PendingMultisigChainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol {
    func createMultisigChainSyncService(
        for chain: ChainModel,
        selectedMultisigAccount: DelegatedAccount.MultisigAccountModel
    ) -> PendingMultisigChainSyncServiceProtocol {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let pendingCallHashesOperationFactory = MultisigStorageOperationFactory(
            storageRequestFactory: storageRequestFactory
        )
        let remoteOperationUpdateService = MultisigPendingOperationsUpdatingService(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
        let predicate = NSPredicate.pendingMultisigOperations(
            for: chain.chainId,
            multisigAccountId: selectedMultisigAccount.accountId
        )
        let repository = storageFacade.createRepository(
            filter: predicate,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(MultisigPendingOperationMapper())
        )
        let localStorageSyncService = PendingMultisigLocalStorageSyncService(
            multisigAccount: selectedMultisigAccount,
            chain: chain,
            chainRegistry: chainRegistry,
            pendingCallHashesOperationFactory: pendingCallHashesOperationFactory,
            remoteOperationUpdateService: remoteOperationUpdateService,
            pendingOperationsRepository: AnyDataProviderRepository(repository),
            operationManager: operationManager
        )

        return PendingMultisigChainSyncService(
            multisigAccount: selectedMultisigAccount,
            chain: chain,
            localStorageSyncService: localStorageSyncService,
            pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
            remoteOperationUpdateService: remoteOperationUpdateService
        )
    }
}
