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
    private let configProvider: GlobalConfigProviding

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        configProvider: GlobalConfigProviding,
        operationManager: OperationManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.configProvider = configProvider
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
            operationQueue: operationQueue,
            logger: Logger.shared
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

        let remoteFetchFactory = PendingMultisigRemoteFetchFactory(
            multisigAccountId: selectedMultisigAccount.accountId,
            chain: chain,
            chainRegistry: chainRegistry,
            pendingCallHashesOperationFactory: pendingCallHashesOperationFactory,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
            blockNumberOperationFactory: BlockNumberOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            configProvider: configProvider,
            operationManager: operationManager
        )
        let localSyncFactory = PendingMultisigLocalSyncFactory(
            multisigAccount: selectedMultisigAccount,
            chain: chain,
            pendingOperationsRepository: AnyDataProviderRepository(repository)
        )

        return PendingMultisigChainSyncService(
            multisigAccount: selectedMultisigAccount,
            chain: chain,
            localSyncFactory: localSyncFactory,
            remoteFetchFactory: remoteFetchFactory,
            pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
            remoteOperationUpdateService: remoteOperationUpdateService,
            operationManager: operationManager
        )
    }
}
