import Foundation
import Keystore_iOS
import Foundation_iOS

struct CurrencyViewFactory {
    static func createView() -> CurrencyViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            assertionFailure("Failed to get currencyManager")
            return nil
        }
        let interactor = CurrencyInteractor(
            currencyManager: currencyManager,
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
