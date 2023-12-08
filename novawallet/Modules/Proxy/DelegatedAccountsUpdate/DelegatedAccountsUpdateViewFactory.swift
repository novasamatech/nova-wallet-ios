import Foundation
import SoraFoundation

struct DelegatedAccountsUpdateViewFactory {
    static func createView() -> DelegatedAccountsUpdateViewProtocol? {
        let interactor = DelegatedAccountsUpdateInteractor(
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )
        let wireframe = DelegatedAccountsUpdateWireframe()

        let presenter = DelegatedAccountsUpdatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelsFactory: DelegatedAccountsUpdateFactory(),
            localizationManager: LocalizationManager.shared
        )

        let view = DelegatedAccountsUpdateViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
