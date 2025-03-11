import Foundation

struct SelectRampProviderViewFactory {
    static func createView() -> SelectRampProviderViewProtocol? {
        let interactor = SelectRampProviderInteractor()
        let wireframe = SelectRampProviderWireframe()

        let presenter = SelectRampProviderPresenter(interactor: interactor, wireframe: wireframe)

        let view = SelectRampProviderViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
