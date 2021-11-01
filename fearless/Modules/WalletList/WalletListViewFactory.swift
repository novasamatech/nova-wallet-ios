import Foundation

struct WalletListViewFactory {
    static func createView() -> WalletListViewProtocol? {
        

        let interactor = WalletListInteractor(
            selectedMetaAccount: <#T##MetaAccountModel#>,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared
        )

        let wireframe = WalletListWireframe()

        let presenter = WalletListPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
