import Foundation

struct YourWalletsViewFactory {
    static func createView(chain: ChainAsset, address: AccountAddress?) -> YourWalletsViewProtocol? {
        let interactor = YourWalletsInteractor()
        let wireframe = YourWalletsWireframe()

        let presenter = YourWalletsPresenter(interactor: interactor, wireframe: wireframe)

        let view = YourWalletsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
