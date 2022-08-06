import Foundation
import SoraFoundation

struct ParitySignerTxQrViewFactory {
    static func createView(with _: Data, completion _: ParitySignerSigningClosure) -> ParitySignerTxQrViewProtocol? {
        let interactor = ParitySignerTxQrInteractor()
        let wireframe = ParitySignerTxQrWireframe()

        let presenter = ParitySignerTxQrPresenter(interactor: interactor, wireframe: wireframe)

        let view = ParitySignerTxQrViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
