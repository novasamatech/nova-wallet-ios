import Foundation
import SoraFoundation

struct ParitySignerTxQrViewFactory {
    static func createView(
        with _: Data,
        metaId _: String,
        chainId _: ChainModel.Id,
        completion: @escaping TransactionSigningClosure
    ) -> ParitySignerTxQrViewProtocol? {
        let interactor = ParitySignerTxQrInteractor()
        let wireframe = ParitySignerTxQrWireframe()

        let presenter = ParitySignerTxQrPresenter(
            interactor: interactor,
            wireframe: wireframe,
            completion: completion,
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )

        let view = ParitySignerTxQrViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
