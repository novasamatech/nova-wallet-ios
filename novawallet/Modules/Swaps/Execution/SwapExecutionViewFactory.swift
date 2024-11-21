import Foundation

struct SwapExecutionViewFactory {
    static func createView() -> SwapExecutionViewProtocol? {
        let interactor = SwapExecutionInteractor()
        let wireframe = SwapExecutionWireframe()

        let presenter = SwapExecutionPresenter(interactor: interactor, wireframe: wireframe)

        let view = SwapExecutionViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}