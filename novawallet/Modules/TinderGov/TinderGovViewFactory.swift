import Foundation

struct TinderGovViewFactory {
    static func createView() -> TinderGovViewProtocol? {
        let interactor = TinderGovInteractor()
        let wireframe = TinderGovWireframe()

        let presenter = TinderGovPresenter(interactor: interactor, wireframe: wireframe)

        let view = TinderGovViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
