import Foundation
import SoraFoundation
import SoraUI

struct DelegatedAccountsUpdateViewFactory {
    static func createView(
        initWallets: [ManagedMetaAccountModel],
        completion: @escaping () -> Void
    ) -> DelegatedAccountsUpdateViewProtocol? {
        let interactor = DelegatedAccountsUpdateInteractor(
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )
        let wireframe = DelegatedAccountsUpdateWireframe(completion: completion)

        let presenter = DelegatedAccountsUpdatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelsFactory: DelegatedAccountsUpdateFactory(),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            initWallets: initWallets
        )

        let view = DelegatedAccountsUpdateViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

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
