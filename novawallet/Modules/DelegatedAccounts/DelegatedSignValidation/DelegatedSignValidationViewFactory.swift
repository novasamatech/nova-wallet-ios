import Foundation

struct DelegatedSignValidationViewFactory {
    static func createView() -> DelegatedSignValidationViewProtocol? {
        let interactor = DelegatedSignValidationInteractor()
        let wireframe = DelegatedSignValidationWireframe()

        let presenter = DelegatedSignValidationPresenter(interactor: interactor, wireframe: wireframe)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
