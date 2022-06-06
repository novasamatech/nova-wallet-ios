import Foundation

struct ParaStkRebondViewFactory {
    static func createView() -> ParaStkRebondViewProtocol? {
        let interactor = ParaStkRebondInteractor()
        let wireframe = ParaStkRebondWireframe()

        let presenter = ParaStkRebondPresenter(interactor: interactor, wireframe: wireframe)

        let view = ParaStkRebondViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
