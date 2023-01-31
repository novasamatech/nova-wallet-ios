import Foundation

struct DelegateInfoDetailsViewFactory {
    static func createView() -> DelegateInfoDetailsViewProtocol? {
        let interactor = DelegateInfoDetailsInteractor()
        let wireframe = DelegateInfoDetailsWireframe()

        let presenter = DelegateInfoDetailsPresenter(interactor: interactor, wireframe: wireframe)

        let view = DelegateInfoDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}