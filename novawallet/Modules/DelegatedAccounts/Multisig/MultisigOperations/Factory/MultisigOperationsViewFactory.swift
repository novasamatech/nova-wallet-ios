import Foundation
import Foundation_iOS

final class MultisigOperationsViewFactory {
    static func createView() -> MultisigOperationsViewProtocol? {
        guard let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let wireframe = MultisigOperationsWireframe()

        let interactor = MultisigOperationsInteractor(
            wallet: selectedWallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: operationQueue,
            pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared
        )

        let viewModelFactory = MultisigOperationsViewModelFactory()

        let localizationManager = LocalizationManager.shared

        let presenter = MultisigOperationsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            wallet: selectedWallet,
            localizationManager: localizationManager
        )

        let controller = MultisigOperationsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = controller
        interactor.presenter = presenter

        return controller
    }
}
