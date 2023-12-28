import Foundation
import SoraFoundation
import SoraUI

struct ProxiedsUpdateViewFactory {
    static func createView(
        initWallets: [ManagedMetaAccountModel]
    ) -> ProxiedsUpdateViewProtocol? {
        let interactor = ProxiedsUpdateInteractor(
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )
        let wireframe = ProxiedsUpdateWireframe()

        let presenter = ProxiedsUpdatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelsFactory: ProxiedsUpdateFactory(),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            initWallets: initWallets
        )

        let view = ProxiedsUpdateViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        let contentHeight = presenter.preferredContentHeight()
        let preferredContentSize = max(0, min(contentHeight, maxHeight))

        view.preferredContentSize = .init(
            width: 0,
            height: preferredContentSize
        )

        return view
    }
}
