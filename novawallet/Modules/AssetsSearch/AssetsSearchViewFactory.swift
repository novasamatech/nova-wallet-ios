import Foundation

struct AssetsSearchViewFactory {
    static func createView() -> AssetsSearchViewProtocol? {
        let interactor = AssetsSearchInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            logger: Logger.shared
        )

        let wireframe = AssetsSearchWireframe()

        let presenter = AssetsSearchPresenter(interactor: interactor, wireframe: wireframe)

        let view = AssetsSearchViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
