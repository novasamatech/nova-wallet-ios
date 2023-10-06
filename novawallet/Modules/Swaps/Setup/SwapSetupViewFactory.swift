import Foundation
import SoraFoundation

struct SwapSetupViewFactory {
    static func createView() -> SwapSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager))

        let interactor = SwapSetupInteractor()
        let wireframe = SwapSetupWireframe()

        let presenter = SwapSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = SwapSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
