import Foundation
import Foundation_iOS
import SubstrateSdk
import Keystore_iOS
import Operation_iOS

enum StakingMainViewFactory {
    static func createView(
        for stakingOption: Multistaking.ChainAssetOption,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        ahmInfoSnapshot: AHMInfoService.Snapshot
    ) -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared

        let interactor = createInteractor(
            with: settings,
            stakingOption: stakingOption,
            ahmInfoSnapshot: ahmInfoSnapshot
        )
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

        let localizationManager = LocalizationManager.shared

        let presenter = StakingMainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            stakingOption: stakingOption,
            childPresenterFactory: childPresenterFactory,
            viewModelFactory: StakingMainViewModelFactory(),
            ahmViewModelFactory: AHMInfoViewModelFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = StakingMainViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        with settings: SettingsManagerProtocol,
        stakingOption: Multistaking.ChainAssetOption,
        ahmInfoSnapshot: AHMInfoService.Snapshot
    ) -> StakingMainInteractor {
        let mapper = AnyCoreDataMapper(StakingRewardsFilterMapper())
        let facade = UserDataStorageFacade.shared
        let stakingRewardsFilterRepository = AnyDataProviderRepository(facade.createRepository(mapper: mapper))

        let ahmInfoFactory = AHMFullInfoFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            ahmInfoService: ahmInfoSnapshot.restoreService(with: \.ahmStakingAlertClosedChains)
        )

        return .init(
            ahmInfoFactory: ahmInfoFactory,
            settingsManager: settings,
            stakingOption: stakingOption,
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            stakingRewardsFilterRepository: stakingRewardsFilterRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
