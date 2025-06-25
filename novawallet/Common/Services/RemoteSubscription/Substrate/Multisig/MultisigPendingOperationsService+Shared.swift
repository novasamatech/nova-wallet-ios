import Foundation
import Operation_iOS

extension MultisigPendingOperationsService {
    static let shared: MultisigPendingOperationsServiceProtocol = {
        let walletSettings = SelectedWalletSettings.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let pendingMultisigQueue = OperationManagerFacade.pendingMultisigQueue
        let pendingMultisigOperationManager = OperationManager(operationQueue: pendingMultisigQueue)

        let coreDataRepository: CoreDataRepository<Multisig.PendingOperation, CDMultisigPendingOperation>
        coreDataRepository = substrateStorageFacade.createRepository(
            mapper: AnyCoreDataMapper(MultisigPendingOperationMapper())
        )

        let pendingMultisigChainSyncServiceFactory = PendingMultisigChainSyncServiceFactory(
            chainRegistry: chainRegistry,
            substrateStorageFacade: substrateStorageFacade,
            operationManager: pendingMultisigOperationManager,
            operationQueue: pendingMultisigQueue
        )
        let multisigCallFetchFactory = MultisigCallFetchFactory(
            chainRegistry: chainRegistry,
            blockQueryFactory: BlockEventsQueryFactory(operationQueue: pendingMultisigQueue)
        )
        let eventsUpdatingService = MultisigEventsUpdatingService(
            chainRegistry: chainRegistry,
            operationQueue: pendingMultisigQueue
        )
        let callDataSyncService = MultisigCallDataSyncService(
            chainRegistry: chainRegistry,
            callFetchFactory: multisigCallFetchFactory,
            eventsUpdatingService: eventsUpdatingService,
            pendingOperationsRepository: AnyDataProviderRepository(coreDataRepository),
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            operationManager: pendingMultisigOperationManager
        )

        return MultisigPendingOperationsService(
            selectedMetaAccount: walletSettings.value,
            chainRegistry: chainRegistry,
            callDataSyncService: callDataSyncService,
            chainSyncServiceFactory: pendingMultisigChainSyncServiceFactory
        )
    }()
}
