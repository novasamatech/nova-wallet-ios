import Foundation
import SoraFoundation
import SoraUI

struct DelegatedAccountsUpdateViewFactory {
    static func createView(initState: DelegatedAccountsUpdateState?) -> DelegatedAccountsUpdateViewProtocol? {
        let interactor = DelegatedAccountsUpdateInteractor(
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )
        let wireframe = DelegatedAccountsUpdateWireframe()

        let presenter = DelegatedAccountsUpdatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelsFactory: DelegatedAccountsUpdateFactory(),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            initState: initState
        )

        let view = DelegatedAccountsUpdateViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter
        
        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        let contentHeight = presenter.preferredContentHeight()
        let preferredContentSize = min(0, maxHeight)

        view.preferredContentSize = .init(
            width: 0,
            height: preferredContentSize
        )

        return view
    }
}
