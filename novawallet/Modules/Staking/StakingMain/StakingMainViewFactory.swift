import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore
import RobinHood

final class StakingMainViewFactory: StakingMainViewFactoryProtocol {
    static func createView() -> StakingMainViewProtocol? {
        let settings = SettingsManager.shared

        guard let sharedState = try? createSharedState() else {
            return nil
        }

        // MARK: - View

        let view = StakingMainViewController(nib: R.nib.stakingMainViewController)
        view.localizationManager = LocalizationManager.shared
        view.iconGenerator = NovaIconGenerator()
        view.uiFactory = UIFactory()

        // MARK: - Interactor

        let interactor = createInteractor(state: sharedState, settings: settings)

        // MARK: - Router

        let wireframe = StakingMainWireframe(state: sharedState)

        // MARK: - Presenter

        let viewModelFacade = StakingViewModelFacade()
        let analyticsVMFactoryBuilder: AnalyticsRewardsViewModelFactoryBuilder
            = { chainAsset, balanceViewModelFactory in
                AnalyticsRewardsViewModelFactory(
                    assetInfo: chainAsset.assetDisplayInfo,
                    balanceViewModelFactory: balanceViewModelFactory,
                    calendar: Calendar(identifier: .gregorian)
                )
            }

        let logger = Logger.shared

        let stateViewModelFactory = StakingStateViewModelFactory(
            analyticsRewardsViewModelFactoryBuilder: analyticsVMFactoryBuilder,
            logger: logger
        )
        let networkInfoViewModelFactory = NetworkInfoViewModelFactory()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingMainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            viewModelFacade: viewModelFacade,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger
        )

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        state: StakingSharedState,
        settings: SettingsManagerProtocol
    ) -> StakingMainInteractor {
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let accountProviderFactory = AccountProviderFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: operationManager,
            logger: logger
        )

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let chainItemRepository = substrateRepositoryFactory.createChainStorageItemRepository()

        let stakingRemoteSubscriptionService = StakingRemoteSubscriptionService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: chainItemRepository,
            operationManager: operationManager,
            logger: logger
        )

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let substrateDataProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager
        )

        let childSubscriptionFactory = ChildSubscriptionFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager,
            eventCenter: EventCenter.shared,
            logger: logger
        )

        let stakingAccountUpdatingService = StakingAccountUpdatingService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            substrateRepositoryFactory: substrateRepositoryFactory,
            substrateDataProviderFactory: substrateDataProviderFactory,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return StakingMainInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            sharedState: state,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            stakingRemoteSubscriptionService: stakingRemoteSubscriptionService,
            stakingAccountUpdatingService: stakingAccountUpdatingService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingServiceFactory: serviceFactory,
            accountProviderFactory: accountProviderFactory,
            eventCenter: EventCenter.shared,
            operationManager: operationManager,
            eraInfoOperationFactory: NetworkStakingInfoOperationFactory(),
            applicationHandler: ApplicationHandler(),
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            commonSettings: settings,
            logger: logger
        )
    }

    private static func createSharedState() throws -> StakingSharedState {
        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingSettings = StakingAssetSettings(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            settings: SettingsManager.shared
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let stakingAnalyticsLocalSubscriptionFactory = StakingAnalyticsLocalSubscriptionFactory(
            storageFacade: storageFacade
        )

        return StakingSharedState(
            settings: stakingSettings,
            eraValidatorService: nil,
            rewardCalculationService: nil,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            stakingAnalyticsLocalSubscriptionFactory: stakingAnalyticsLocalSubscriptionFactory
        )
    }
}
