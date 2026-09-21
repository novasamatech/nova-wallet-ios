import Foundation
import Foundation_iOS
import Operation_iOS

extension StartStakingInfoViewFactory {
    static func createSubtensorView(
        for stakingOption: Multistaking.ChainAssetOption
    ) -> StartStakingInfoViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let stateFactory = StakingSharedStateFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            delegatedAccountSyncService: nil,
            eventCenter: EventCenter.shared,
            syncOperationQueue: operationQueue,
            repositoryOperationQueue: operationQueue,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        guard
            let state = try? stateFactory.createSubtensorStaking(for: stakingOption),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let strategiesDataSource = SubtensorStakingStrategiesMockDataSource()
        let interactor = createSubtensorInteractor(
            state: state,
            currencyManager: currencyManager,
            strategiesDataSource: strategiesDataSource
        )

        let wireframe = StartStakingInfoSubtensorWireframe(
            state: state,
            strategiesDataSource: strategiesDataSource
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: stakingOption.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let startStakingViewModelFactory = StartStakingViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let presenter = StartStakingInfoSubtensorPresenter(
            chainAsset: stakingOption.chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            subtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactory(),
            balanceDerivationFactory: StakingTypeBalanceFactory(stakingType: stakingOption.type),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let view = StartStakingInfoSubtensorViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createSubtensorInteractor(
        state: SubtensorStakingSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol,
        strategiesDataSource: SubtensorStakingStrategiesDataSourceProtocol
    ) -> StartStakingInfoSubtensorInteractor {
        let stakingDashboardProviderFactory = StakingDashboardProviderFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let networkInfoFactory = SubtensorNetworkInfoFactory(
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: state.stakingOption.chainAsset.chain.chainId,
                chainRegistry: state.chainRegistry
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return StartStakingInfoSubtensorInteractor(
            state: state,
            selectedWalletSettings: SelectedWalletSettings.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            networkInfoFactory: networkInfoFactory,
            strategiesDataSource: strategiesDataSource,
            currencyManager: currencyManager,
            sharedOperation: state.startSharedOperation(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
