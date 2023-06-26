import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore
import RobinHood

enum StakingMainViewFactory {
    static func createView(for stakingOption: Multistaking.ChainAssetOption) -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared

        let interactor = StakingMainInteractor(commonSettings: settings)
        let wireframe = StakingMainWireframe()

        let applicationHandler = SecurityLayerService.shared.applicationHandlingProxy
            .addApplicationHandler()

        let presenter = StakingMainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            wallet: SelectedWalletSettings.shared.value,
            stakingOption: stakingOption,
            accountManagementFilter: AccountManagementFilter(),
            childPresenterFactory: StakingMainPresenterFactory(applicationHandler: applicationHandler),
            viewModelFactory: StakingMainViewModelFactory(),
            logger: Logger.shared
        )

        let view = StakingMainViewController(
            presenter: presenter, localizationManager: LocalizationManager.shared
        )

        view.iconGenerator = NovaIconGenerator()
        view.uiFactory = UIFactory()

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
