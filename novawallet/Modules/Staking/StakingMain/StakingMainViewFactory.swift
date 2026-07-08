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

        let noticesProvider = StakingNoticesFacade.sharedProvider

        let interactor = createInteractor(
            with: settings,
            stakingOption: stakingOption,
            noticesProvider: noticesProvider
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
            noticesProvider: noticesProvider,
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
        noticesProvider: StakingNoticesProviding
    ) -> StakingMainInteractor {
        let mapper = AnyCoreDataMapper(StakingRewardsFilterMapper())
        let facade = UserDataStorageFacade.shared
        let stakingRewardsFilterRepository = AnyDataProviderRepository(facade.createRepository(mapper: mapper))

        let ahmInfoFactory = AHMFullInfoFactory(filterSetKeypath: \.ahmStakingAlertClosedChains)

        return .init(
            ahmInfoFactory: ahmInfoFactory,
            settingsManager: settings,
            stakingOption: stakingOption,
            noticesProvider: noticesProvider,
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            stakingRewardsFilterRepository: stakingRewardsFilterRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
