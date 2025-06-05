import UIKit
import UIKit_iOS
import Foundation_iOS

final class DelegatedAccountsUpdateViewFactory {
    static func createView(initWallets: [ManagedMetaAccountModel]) -> DelegatedAccountsUpdateViewController? {
        let walletListLocalSubscriptionFactory = WalletListLocalSubscriptionFactory.shared

        let interactor = DelegatedAccountsUpdateInteractor(
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let wireframe = DelegatedAccountsUpdateWireframe()

        let viewModelsFactory = DelegatedAccountsUpdateFactory()

        let presenter = DelegatedAccountsUpdatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelsFactory: viewModelsFactory,
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

        let maxHeight = UIScreen.main.bounds.height * 0.925
        let contentHeight = presenter.preferredContentHeight()
        let preferredContentHeight = max(0, min(contentHeight, maxHeight))

        view.preferredContentSize = CGSize(width: 0.0, height: preferredContentHeight)

        return view
    }
}
