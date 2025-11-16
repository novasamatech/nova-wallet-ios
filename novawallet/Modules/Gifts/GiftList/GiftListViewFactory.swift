import Foundation

struct GiftListViewFactory {
    static func createView() -> GiftListViewProtocol? {
        let interactor = GiftListInteractor()
        let wireframe = GiftListWireframe()

        let presenter = GiftListPresenter(interactor: interactor, wireframe: wireframe)

        let view = GiftListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}