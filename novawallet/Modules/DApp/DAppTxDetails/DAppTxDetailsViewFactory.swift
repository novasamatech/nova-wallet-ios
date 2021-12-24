import Foundation
import SubstrateSdk
import SoraFoundation

struct DAppTxDetailsViewFactory {
    static func createView(from txDetails: JSON) -> DAppTxDetailsViewProtocol? {
        let interactor = DAppTxDetailsInteractor(
            txDetails: txDetails,
            preprocessor: ExtrinsicJSONProcessor(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = DAppTxDetailsWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = DAppTxDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = DAppTxDetailsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
