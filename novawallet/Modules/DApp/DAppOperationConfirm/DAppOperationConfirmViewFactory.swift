import Foundation

struct DAppOperationConfirmViewFactory {
    static func createView(
        for request: DAppOperationRequest,
        delegate: DAppOperationConfirmDelegate
    ) -> DAppOperationConfirmViewProtocol? {
        let interactor = DAppOperationConfirmInteractor(request: request)
        let wireframe = DAppOperationConfirmWireframe()

        let presenter = DAppOperationConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = DAppOperationConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
