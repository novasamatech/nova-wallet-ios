import Foundation

struct StakingDashboardViewFactory {
    static func createView() -> StakingDashboardViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = StakingDashboardWireframe()

        let presenter = StakingDashboardPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingDashboardViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> StakingDashboardInteractor? {
        let walletSettings = SelectedWalletSettings.shared

        guard let wallet = walletSettings.value, let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let syncService = MultistakingServiceFactory.createService(
            for: wallet,
            offchainUrl: ApplicationConfig.shared.multistakingURL,
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
            syncService: syncService,
            walletSettings: walletSettings,
            chainsStore: ChainsStore(chainRegistry: chainRegistry),
            eventCenter: EventCenter.shared,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager
        )
    }
}
