import Foundation
import Operation_iOS
import SubstrateSdk

protocol PendingMultisigChainSyncServiceFactoryProtocol {
    func createMultisigChainSyncService(
        for chain: ChainModel,
        selectedMultisigAccount: DelegatedAccount.MultisigAccountModel,
        knownCallData: [Multisig.PendingOperation.Key: JSON],
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
        selectedMultisigAccount: DelegatedAccount.MultisigAccountModel,
        knownCallData: [Multisig.PendingOperation.Key: JSON],
        operationQueue: OperationQueue
    ) -> PendingMultisigChainSyncServiceProtocol {
        let pendingMultisigsQueue = OperationManagerFacade.pendingMultisigQueue
        let multisigSyncOperationManager = OperationManager(operationQueue: pendingMultisigsQueue)

        let storageFacade = UserDataStorageFacade.shared

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: multisigSyncOperationManager
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

        return PendingMultisigChainSyncService(
            multisigAccount: selectedMultisigAccount,
            chain: chain,
            chainRegistry: chainRegistry,
            pendingCallHashesOperationFactory: pendingCallHashesOperationFactory,
            remoteOperationUpdateService: remoteOperationUpdateService,
            pendingOperationsRepository: AnyDataProviderRepository(repository),
            knownCallData: knownCallData,
            operationQueue: operationQueue
        )
    }
}
