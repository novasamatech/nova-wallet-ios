import Foundation
import SoraKeystore

struct CurrencyViewFactory {
    static func createView() -> CurrencyViewProtocol? {
        let interactor = CurrencyInteractor(
            currencyRepository: CurrencyRepository.shared,
            userCurrencyRepository: UserCurrencyRepository(
                currencyRepository: CurrencyRepository.shared,
                settingManager: SettingsManager.shared
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = CurrencyWireframe()

        let presenter = CurrencyPresenter(interactor: interactor, wireframe: wireframe)

        let view = CurrencyViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
