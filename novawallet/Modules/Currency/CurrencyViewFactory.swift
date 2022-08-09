import Foundation
import SoraKeystore
import SoraFoundation

struct CurrencyViewFactory {
    static func createView() -> CurrencyViewProtocol? {
        let interactor = CurrencyInteractor(
            currencyManager: CurrencyManager.shared!,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = CurrencyWireframe()

        let presenter = CurrencyPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = CurrencyViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
