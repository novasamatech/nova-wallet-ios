import Foundation
import Operation_iOS
import SubstrateSdk

protocol PendingMultisigChainSyncServiceFactoryProtocol {
    func createMultisigChainSyncService(
        for chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        operationQueue: OperationQueue
    ) -> PendingMultisigChainSyncServiceProtocol
}

final class PendingMultisigChainSyncServiceFactory {
    private let chainRegistry: ChainRegistryProtocol
    private let substrateStorageFacade: StorageFacadeProtocol
    
    init(
        chainRegistry: ChainRegistryProtocol,
        substrateStorageFacade: StorageFacadeProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.substrateStorageFacade = substrateStorageFacade
    }
}

// MARK: - PendingMultisigChainSyncServiceFactoryProtocol

extension PendingMultisigChainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol {
    func createMultisigChainSyncService(
        for chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        operationQueue: OperationQueue
    ) -> PendingMultisigChainSyncServiceProtocol {
        let assetsSyncOperationQueue = OperationManagerFacade.assetsSyncQueue
        let assetsSyncOperationManager = OperationManager(operationQueue: assetsSyncOperationQueue)

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: assetsSyncOperationManager
        )
        let pendingCallHashesOperationFactory = MultisigStorageOperationFactory(
            storageRequestFactory: storageRequestFactory
        )
        let remoteOperationUpdateService = MultisigPendingOperationsUpdatingService(
            chainRegistry: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: operationQueue
        )
            
        
        return PendingMultisigChainSyncService(
            wallet: selectedMetaAccount,
            chain: chain,
            chainRegistry: chainRegistry,
            pendingCallHashesOperationFactory: pendingCallHashesOperationFactory,
            remoteOperationUpdateService: remoteOperationUpdateService,
            repositoryCachingFactory: substrateStorageFacade,
            operationQueue: operationQueue
        )
    }
}
