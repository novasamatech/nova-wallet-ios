import Foundation
import SoraFoundation

struct TransferSetupViewFactory {
    static func createView(
        from _: ChainAsset,
        recepient _: DisplayAddress?
    ) -> TransferSetupViewProtocol? {
        let interactor = TransferSetupInteractor()
        let wireframe = TransferSetupWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = TransferSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = TransferSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
