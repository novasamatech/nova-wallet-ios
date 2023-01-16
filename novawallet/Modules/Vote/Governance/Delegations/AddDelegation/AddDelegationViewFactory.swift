import Foundation

struct AddDelegationViewFactory {
    static func createView() -> AddDelegationViewProtocol? {
        let interactor = AddDelegationInteractor()
        let wireframe = AddDelegationWireframe()

        let presenter = AddDelegationPresenter(interactor: interactor, wireframe: wireframe)

        let view = AddDelegationViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
