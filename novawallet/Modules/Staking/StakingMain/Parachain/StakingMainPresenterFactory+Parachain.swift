import Foundation
import RobinHood
import SoraFoundation

extension StakingMainPresenterFactory {
    func createParachainPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingParachainPresenter {
        let sharedState = createParachainSharedState(for: stakingAssetSettings)

        // MARK: - Interactor

        let interactor = createParachainInteractor(state: sharedState)

        // MARK: - Router

        let wireframe = StakingParachainWireframe(state: sharedState)

        // MARK: - Presenter

        let networkInfoViewModelFactory = ParachainStaking.NetworkInfoViewModelFactory()
        let stateViewModelFactory = ParaStkStateViewModelFactory()

        let presenter = StakingParachainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            stateViewModelFactory: stateViewModelFactory,
            logger: Logger.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    func createParachainInteractor(state: ParachainStakingSharedState) -> StakingParachainInteractor {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)
        let eventCenter = EventCenter.shared
        let logger = Logger.shared

        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()

        let stakingAccountService = ParachainStaking.AccountSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: operationManager,
            logger: logger
        )

        let stakingAssetService = ParachainStaking.StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: operationManager,
            logger: logger
        )

        let serviceFactory = ParachainStakingServiceFactory(
            stakingProviderFactory: state.stakingLocalSubscriptionFactory,
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        let stakingDurationFactory = ParaStkDurationOperationFactory()
        let networkInfoFactory = ParaStkNetworkInfoOperationFactory(durationFactory: stakingDurationFactory)

        return StakingParachainInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            sharedState: state,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            stakingAssetSubscriptionService: stakingAssetService,
            stakingAccountSubscriptionService: stakingAccountService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingServiceFactory: serviceFactory,
            networkInfoFactory: networkInfoFactory,
            scheduledRequestsFactory: ParachainStaking.ScheduledRequestsQueryFactory(operationQueue: operationQueue),
            eventCenter: eventCenter,
            applicationHandler: ApplicationHandler(),
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createParachainSharedState(
        for stakingAssetSettings: StakingAssetSettings
    ) -> ParachainStakingSharedState {
        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingLocalSubscriptionFactory = ParachainStakingLocalSubscriptionFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return ParachainStakingSharedState(
            settings: stakingAssetSettings,
            collatorService: nil,
            rewardCalculationService: nil,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory
        )
    }
}
