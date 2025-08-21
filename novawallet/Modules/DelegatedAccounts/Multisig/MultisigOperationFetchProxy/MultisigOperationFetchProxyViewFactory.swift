import Foundation
import Operation_iOS
import Foundation_iOS
import SubstrateSdk

struct MultisigOperationFetchProxyViewFactory {
    static func createView(
        for operationKey: Multisig.PendingOperation.Key,
        flowState: MultisigOperationsFlowState?
    ) -> MultisigOperationFetchProxyViewProtocol? {
        guard let interactor = createInteractor(for: operationKey) else {
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
        for operationKey: Multisig.PendingOperation.Key
    ) -> MultisigOperationFetchProxyInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let chain = try? chainRegistry.getChainOrError(for: operationKey.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let chainProvider = ChainRegistryChainProvider(chainRegistry: chainRegistry)
        let runtimeCodingServiceProvider = ChainRegistryRuntimeCodingServiceProvider(chainRegistry: chainRegistry)

        let pendingOperationsProvider = MultisigOperationProviderProxy(
            pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
            callFormattingFactory: CallFormattingOperationFactory(
                chainProvider: chainProvider,
                runtimeCodingServiceProvider: runtimeCodingServiceProvider,
                walletRepository: walletRepository,
                operationQueue: operationQueue
            ),
            operationQueue: operationQueue
        )

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
            pendingOperationProviderProxy: pendingOperationsProvider,
            pendingOperationsRepository: AnyDataProviderRepository(coreDataRepository),
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
