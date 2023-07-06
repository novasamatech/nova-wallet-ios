import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore
import RobinHood

enum StakingMainViewFactory {
    static func createView(for stakingOption: Multistaking.ChainAssetOption) -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared

        let interactor = createInteractor(with: settings, stakingOption: stakingOption)
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

    private static func createInteractor(
        with settings: SettingsManagerProtocol,
        stakingOption: Multistaking.ChainAssetOption
    ) -> StakingMainInteractor {
        let mapper = AnyCoreDataMapper(StakingRewardsFilterMapper())
        let facade = UserDataStorageFacade.shared
        let stakingRewardsFilterRepository = AnyDataProviderRepository(facade.createRepository(mapper: mapper))

        return .init(
            stakingOption: stakingOption,
            selectedWalletSettings: SelectedWalletSettings.shared,
            commonSettings: settings,
            eventCenter: EventCenter.shared,
            stakingRewardsFilterRepository: stakingRewardsFilterRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
