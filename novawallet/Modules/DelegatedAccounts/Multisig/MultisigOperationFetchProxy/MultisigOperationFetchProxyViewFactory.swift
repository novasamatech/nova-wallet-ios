import Foundation
import Operation_iOS
import Foundation_iOS
import SubstrateSdk

struct MultisigOperationFetchProxyViewFactory {
    static func createView(
        for operationKey: Multisig.PendingOperation.Key
    ) -> MultisigOperationFetchProxyViewProtocol? {
        let flowState = MultisigOperationsFlowState()

        guard let interactor = createInteractor(for: operationKey, flowState: flowState) else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let wireframe = MultisigOperationFetchProxyWireframe(flowState: flowState)

        let presenter = MultisigOperationFetchProxyPresenter(
            wireframe: wireframe,
            interactor: interactor,
            localizationManager: localizationManager
        )

        let view = MultisigOperationFetchProxyViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for operationKey: Multisig.PendingOperation.Key,
        flowState: MultisigOperationsFlowState
    ) -> MultisigOperationFetchProxyInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let chain = try? chainRegistry.getChainOrError(for: operationKey.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)
        let userStorageFacade = UserDataStorageFacade.shared

        let walletRepository = AccountRepositoryFactory(
            storageFacade: userStorageFacade
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let pendingCallHashesOperationFactory = MultisigStorageOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let pendingOperationsFetchFactory = PendingMultisigRemoteFetchFactory(
            multisigAccountId: operationKey.multisigAccountId,
            chain: chain,
            chainRegistry: chainRegistry,
            pendingCallHashesOperationFactory: pendingCallHashesOperationFactory,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain),
            blockNumberOperationFactory: BlockNumberOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            operationManager: operationManager
        )

        let coreDataRepository: CoreDataRepository<Multisig.PendingOperation, CDMultisigPendingOperation>
        coreDataRepository = SubstrateDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(MultisigPendingOperationMapper())
        )

        return MultisigOperationFetchProxyInteractor(
            operationKey: operationKey,
            pendingOperationFetchFactory: pendingOperationsFetchFactory,
            pendingOperationProviderProxy: flowState.getOperationProviderProxy(),
            pendingOperationsRepository: AnyDataProviderRepository(coreDataRepository),
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
