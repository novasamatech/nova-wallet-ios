import Foundation
import Foundation_iOS
import SubstrateSdk
import Keystore_iOS
import Operation_iOS

enum StakingMainViewFactory {
    static func createView(
        for stakingOption: Multistaking.ChainAssetOption,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    ) -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared

        let interactor = createInteractor(with: settings, stakingOption: stakingOption)
        let wireframe = StakingMainWireframe()

        let applicationHandler = SecurityLayerService.shared.applicationHandlingProxy
            .addApplicationHandler()

        let sharedStateFactory = StakingSharedStateFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            delegatedAccountSyncService: delegatedAccountSyncService,
            eventCenter: EventCenter.shared,
            syncOperationQueue: OperationManagerFacade.sharedDefaultQueue,
            repositoryOperationQueue: OperationManagerFacade.sharedDefaultQueue,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let childPresenterFactory = StakingMainPresenterFactory(
            applicationHandler: applicationHandler,
            sharedStateFactory: sharedStateFactory
        )

        let presenter = StakingMainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            stakingOption: stakingOption,
            childPresenterFactory: childPresenterFactory,
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
