import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation
import SoraKeystore

extension StakingMainPresenterFactory {
    func createRelaychainPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingRelaychainPresenter {
        let sharedState = createRelaychainSharedState(for: stakingAssetSettings)

        // MARK: - Interactor

        let interactor = createRelaychainInteractor(state: sharedState)

        // MARK: - Router

        let wireframe = StakingRelaychainWireframe(state: sharedState)

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

        let presenter = StakingRelaychainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            viewModelFacade: viewModelFacade,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        dataValidatingFactory.view = view

        return presenter
    }

    func createRelaychainInteractor(state: StakingSharedState) -> StakingRelaychainInteractor {
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

        let eraCountdownOperationFactory = BabeEraOperationFactory(
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

        return StakingRelaychainInteractor(
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
            logger: logger
        )
    }

    func createRelaychainSharedState(
        for stakingAssetSettings: StakingAssetSettings
    ) -> StakingSharedState {
        let storageFacade = SubstrateDataStorageFacade.shared

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
            settings: stakingAssetSettings,
            eraValidatorService: nil,
            rewardCalculationService: nil,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            stakingAnalyticsLocalSubscriptionFactory: stakingAnalyticsLocalSubscriptionFactory
        )
    }
}
