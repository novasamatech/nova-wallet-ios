import Foundation
import Foundation_iOS

struct StakingDashboardViewFactory {
    static func createView(
        walletNotificationService: WalletNotificationServiceProtocol,
        proxySyncService: ProxySyncServiceProtocol
    ) -> StakingDashboardViewProtocol? {
        let stateObserver = Observable(state: StakingDashboardModel())

        guard
            let interactor = createInteractor(
                for: stateObserver,
                walletNotificationService: walletNotificationService
            ),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = StakingDashboardWireframe(
            stateObserver: stateObserver,
            proxySyncService: proxySyncService
        )

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = StakingDashboardViewModelFactory(
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let presenter = StakingDashboardPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = StakingDashboardViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for stateObserver: Observable<StakingDashboardModel>,
        walletNotificationService: WalletNotificationServiceProtocol
    ) -> StakingDashboardInteractor? {
        let walletSettings = SelectedWalletSettings.shared

        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let stakingConfigProvider = StakingGlobalConfigProvider(
            configUrl: ApplicationConfig.shared.stakingGlobalConfigURL
        )

        let syncServiceFactory = MultistakingSyncServiceFactory(
            stakingConfigProvider: stakingConfigProvider,
            storageFacade: SubstrateDataStorageFacade.shared,
            chainRegistry: chainRegistry
        )

        let stakingDashboardProviderFactory = StakingDashboardProviderFactory(
            chainRegistry: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return .init(
            syncServiceFactory: syncServiceFactory,
            walletSettings: walletSettings,
            chainsStore: ChainsStore(chainRegistry: chainRegistry),
            eventCenter: EventCenter.shared,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stateObserver: stateObserver,
            applicationHandler: ApplicationHandler(),
            walletNotificationService: walletNotificationService,
            currencyManager: currencyManager
        )
    }
}
