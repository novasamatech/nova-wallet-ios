import UIKit
import Foundation_iOS

final class DelegatedAccountsUpdateViewFactory {
    static func createView(initWallets: [ManagedMetaAccountModel]) -> DelegatedAccountsUpdateViewController? {
        let walletListLocalSubscriptionFactory = WalletListLocalSubscriptionFactory.shared

        let interactor = DelegatedAccountsUpdateInteractor(
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let wireframe = DelegatedAccountsUpdateWireframe()

        let walletViewModelFactory = WalletAccountViewModelFactory()

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

        let preferredHeight = view.preferredContentHeight(delegatedModelsCount: 0, revokedModelsCount: 0)
        view.preferredContentSize = CGSize(width: 0.0, height: preferredHeight)

        return view
    }
}
