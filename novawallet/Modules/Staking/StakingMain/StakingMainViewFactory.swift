import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore
import RobinHood

enum StakingMainViewFactory {
    static func createView(for stakingOption: Multistaking.ChainAssetOption) -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared

        // MARK: - View

        let interactor = StakingMainInteractor(commonSettings: settings)

        let wireframe = StakingMainWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let applicationHandler = SecurityLayerService.shared.applicationHandlingProxy.addApplicationHandler()
        let presenter = StakingMainPresenter(
            interactor: interactor,
            childPresenterFactory: StakingMainPresenterFactory(applicationHandler: applicationHandler),
            viewModelFactory: StakingMainViewModelFactory(),
            logger: Logger.shared
        )

        let view = StakingMainViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        view.iconGenerator = NovaIconGenerator()
        view.uiFactory = UIFactory()

        presenter.view = view
        presenter.interactor = interactor

        return view
    }
}
