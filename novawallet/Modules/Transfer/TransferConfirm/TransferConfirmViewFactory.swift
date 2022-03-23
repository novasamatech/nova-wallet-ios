import Foundation
import SoraFoundation

struct TransferConfirmViewFactory {
    static func createView(
        from recepient: AccountAddress,
        amount: Decimal
    ) -> TransferConfirmViewProtocol? {
        let interactor = TransferConfirmInteractor()
        let wireframe = TransferConfirmWireframe()

        let localitionManager = LocalizationManager.shared

        let presenter = TransferConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            recepient: recepient,
            amount: amount
        )

        let view = TransferConfirmViewController(
            presenter: presenter,
            localizationManager: localitionManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
