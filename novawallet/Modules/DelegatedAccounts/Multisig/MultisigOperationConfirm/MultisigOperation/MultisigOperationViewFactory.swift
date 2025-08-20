import Foundation
import Operation_iOS
import Foundation_iOS

struct MultisigOperationViewFactory {
    static func createView(
        for moduleInput: MultisigOperationModuleInput,
        flowState: MultisigOperationsFlowState
    ) -> MultisigOperationViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

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

        let interactor = MultisigOperationInteractor(
            input: moduleInput,
            pendingOperationProvider: pendingOperationsProvider,
            logger: Logger.shared
        )

        let localizationManager = LocalizationManager.shared

        let wireframe = MultisigOperationWireframe(flowState: flowState)

        let presenter = MultisigOperationPresenter(
            wireframe: wireframe,
            interactor: interactor
        )

        let view = MultisigOperationViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
