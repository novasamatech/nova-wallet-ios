import Foundation
import SoraFoundation

struct TokensManageViewFactory {
    static func createView() -> TokensManageViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = TokensManageWireframe()

        let formatter = NumberFormatter.positiveQuantity.localizableResource()
        let viewModelFactory = TokensManageViewModelFactory(quantityFormater: formatter)

        let presenter = TokensManagePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = TokensManageViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> TokensManageInteractor? {
        let repository = SubstrateRepositoryFactory().createChainRepository()

        return .init(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
