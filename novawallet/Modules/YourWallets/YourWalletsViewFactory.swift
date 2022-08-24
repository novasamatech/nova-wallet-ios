import Foundation

struct YourWalletsViewFactory {
    static func createView(
        metaAccounts: [PossibleMetaAccountChainResponse],
        address _: AccountAddress?,
        delegate: YourWalletsDelegate
    ) -> YourWalletsViewProtocol? {
        let interactor = YourWalletsInteractor()
        let wireframe = YourWalletsWireframe()

        let presenter = YourWalletsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            metaAccounts: metaAccounts,
            delegate: delegate
        )

        let view = TestYourWalletsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
