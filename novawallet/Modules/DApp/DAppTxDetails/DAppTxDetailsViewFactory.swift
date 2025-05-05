import Foundation
import SubstrateSdk
import Foundation_iOS

struct DAppTxDetailsViewFactory {
    static func createView(from txDetails: JSON) -> DAppTxDetailsViewProtocol? {
        let processingOperationFactory = PrettyPrintedJSONOperationFactory(preprocessor: ExtrinsicJSONProcessor())
        let interactor = DAppTxDetailsInteractor(
            txDetails: txDetails,
            prettyPrintedJSONOperationFactory: processingOperationFactory,
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
