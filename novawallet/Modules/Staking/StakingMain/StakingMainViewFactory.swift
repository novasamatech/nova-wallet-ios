import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore
import RobinHood

final class StakingMainViewFactory: StakingMainViewFactoryProtocol {
    static func createView() -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared

        // MARK: - View

        let interactor = createInteractor(with: settings)

        let wireframe = StakingMainWireframe()

        let presenter = StakingMainPresenter(
            childPresenterFactory: StakingMainPresenterFactory(),
            viewModelFactory: StakingMainViewModelFactory(),
            logger: Logger.shared
        )

        let view = StakingMainViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        view.iconGenerator = NovaIconGenerator()
        view.uiFactory = UIFactory()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        with settings: SettingsManagerProtocol
    ) -> StakingMainInteractor {
        let stakingSettings = StakingAssetSettings(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            settings: settings
        )

        return StakingMainInteractor(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedWalletSettings: SelectedWalletSettings.shared,
            stakingSettings: stakingSettings,
            commonSettings: settings,
            eventCenter: EventCenter.shared
        )
    }
}
