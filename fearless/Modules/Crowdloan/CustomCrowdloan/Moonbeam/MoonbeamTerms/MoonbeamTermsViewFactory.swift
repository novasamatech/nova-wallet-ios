import Foundation

struct MoonbeamTermsViewFactory {
    static func createView() -> MoonbeamTermsViewProtocol? {
        let interactor = MoonbeamTermsInteractor()
        let wireframe = MoonbeamTermsWireframe()

        let presenter = MoonbeamTermsPresenter(interactor: interactor, wireframe: wireframe)

        let view = MoonbeamTermsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
