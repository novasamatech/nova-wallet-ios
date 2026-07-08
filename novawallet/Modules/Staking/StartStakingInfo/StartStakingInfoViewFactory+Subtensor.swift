import Foundation
import Foundation_iOS

extension StartStakingInfoViewFactory {
    /// Assembles the Nova-generic `StartStakingInfoViewController` wired
    /// with a Subtensor-specific presenter, interactor, and wireframe.
    /// Mirrors the parachain / mythos factory helpers in this module so
    /// the Bittensor "Start Staking" info screen matches other chains
    /// visually and behaviourally, and the "Start staking" button pushes
    /// SubtensorStakingViewFactory's validator picker.
    static func createSubtensorView(
        chainAsset: ChainAsset
    ) -> StartStakingInfoViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createSubtensorInteractor(chainAsset: chainAsset, currencyManager: currencyManager)

        let wireframe = StartStakingInfoSubtensorWireframe(chainAsset: chainAsset)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let startStakingViewModelFactory = StartStakingViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        // [TEMP-TAOSTATS] Phase B temporary numeric data source. Feeds the
        // "Earn up to X%" headline on the info screen with the real
        // cross-validator peak APR. Swap for a Nova-indexer implementation
        // when infra ships Bittensor support — no other wiring changes.
        let dataSource: SubtensorValidatorDataSourceProtocol = {
            if let key = TaoStatsKeyProvider.loadKey() {
                return TaoStatsValidatorDataSource(apiKey: key, session: .shared)
            } else {
                return StubSubtensorValidatorDataSource()
            }
        }()

        let presenter = StartStakingInfoSubtensorPresenter(
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            balanceDerivationFactory: StakingTypeBalanceFactory(stakingType: .subtensor),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            dataSource: dataSource,
            logger: Logger.shared
        )

        let view = StartStakingInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            themeColor: chainAsset.chain.themeColor ?? R.color.colorPolkadotBrand()!
        )

        presenter.view = view
        interactor.basePresenter = presenter

        return view
    }

    private static func createSubtensorInteractor(
        chainAsset: ChainAsset,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingInfoSubtensorInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let stakingDashboardProviderFactory = StakingDashboardProviderFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return StartStakingInfoSubtensorInteractor(
            selectedWalletSettings: selectedWalletSettings,
            selectedChainAsset: chainAsset,
            selectedStakingType: .subtensor,
            sharedOperation: SharedOperation(),
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}
