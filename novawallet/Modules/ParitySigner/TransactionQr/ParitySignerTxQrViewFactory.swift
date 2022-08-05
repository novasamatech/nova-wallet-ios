import Foundation

struct ParitySignerTxQrViewFactory {
    static func createView(with _: Data, completion _: ParitySignerSigningClosure) -> ParitySignerTxQrViewProtocol? {
        let interactor = ParitySignerTxQrInteractor()
        let wireframe = ParitySignerTxQrWireframe()

        let presenter = ParitySignerTxQrPresenter(interactor: interactor, wireframe: wireframe)

        let view = ParitySignerTxQrViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
