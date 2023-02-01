import Foundation

struct DelegationListViewFactory {
    static func createView() -> DelegationListViewProtocol? {
        let interactor = DelegationListInteractor()
        let wireframe = DelegationListWireframe()

        let presenter = DelegationListPresenter(interactor: interactor, wireframe: wireframe)

        let view = DelegationListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
