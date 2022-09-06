import Foundation
import RobinHood
import SoraFoundation
import SubstrateSdk

extension StakingMainPresenterFactory {
    func createParachainPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingParachainPresenter? {
        let sharedState = createParachainSharedState(for: stakingAssetSettings)

        // MARK: - Interactor

        guard let interactor = createParachainInteractor(state: sharedState),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        // MARK: - Router

        let wireframe = StakingParachainWireframe(state: sharedState)

        // MARK: - Presenter

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let networkInfoViewModelFactory = ParachainStaking.NetworkInfoViewModelFactory(priceAssetInfoFactory: priceAssetInfoFactory)
        let stateViewModelFactory = ParaStkStateViewModelFactory(priceAssetInfoFactory: priceAssetInfoFactory)

        let presenter = StakingParachainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            stateViewModelFactory: stateViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            logger: Logger.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    func createParachainInteractor(state: ParachainStakingSharedState) -> StakingParachainInteractor? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)
        let eventCenter = EventCenter.shared
        let logger = Logger.shared

        let repositoryFactory = SubstrateRepositoryFactory()
        let repository = repositoryFactory.createChainStorageItemRepository()

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

        let networkInfoFactory = ParaStkNetworkInfoOperationFactory()

        let blockTimeFactory = BlockTimeOperationFactory(chain: state.settings.value.chain)
        let durationFactory = ParaStkDurationOperationFactory(blockTimeOperationFactory: blockTimeFactory)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let collatorsOperationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

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
            durationOperationFactory: durationFactory,
            scheduledRequestsFactory: ParachainStaking.ScheduledRequestsQueryFactory(operationQueue: operationQueue),
            collatorsOperationFactory: collatorsOperationFactory,
            eventCenter: eventCenter,
            applicationHandler: ApplicationHandler(),
            currencyManager: currencyManager,
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

        let generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return ParachainStakingSharedState(
            settings: stakingAssetSettings,
            collatorService: nil,
            rewardCalculationService: nil,
            blockTimeService: nil,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory
        )
    }
}
