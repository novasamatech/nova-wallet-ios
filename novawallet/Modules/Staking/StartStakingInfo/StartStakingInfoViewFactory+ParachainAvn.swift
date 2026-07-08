import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS

extension StartStakingInfoViewFactory {
    static func createParachainAvnView(
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

        let state: ParachainStakingSharedStateProtocol
        do {
            state = try stateFactory.createParachainAvn(for: stakingOption)
        } catch {
            Logger.shared.error("createParachainAvn failed: \(error)")
            return nil
        }

        guard let currencyManager = CurrencyManager.shared else {
            Logger.shared.error("CurrencyManager.shared was nil for ParachainAvn start-staking")
            return nil
        }

        let interactor = createParachainAvnInteractor(state: state, currencyManager: currencyManager)

        let wireframe = StartStakingInfoParachainWireframe(state: state)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: stakingOption.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )
        let startStakingViewModelFactory = StartStakingViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let presenter = StartStakingInfoParachainPresenter(
            chainAsset: stakingOption.chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            balanceDerivationFactory: StakingTypeBalanceFactory(stakingType: stakingOption.type),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let view = StartStakingInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            themeColor: stakingOption.chainAsset.chain.themeColor ?? R.color.colorPolkadotBrand()!
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createParachainAvnInteractor(
        state: ParachainStakingSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingParachainInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let stakingDurationFactory = ParachainAvnDurationOperationFactory(
            storageRequestFactory: storageRequestFactory,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: state.stakingOption.chainAsset.chain)
        )

        let stakingDashboardProviderFactory = StakingDashboardProviderFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return StartStakingParachainInteractor(
            state: state,
            selectedWalletSettings: selectedWalletSettings,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            currencyManager: currencyManager,
            networkInfoFactory: ParachainAvnNetworkInfoOperationFactory(),
            durationOperationFactory: stakingDurationFactory,
            sharedOperation: state.startSharedOperation(),
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared
        )
    }
}
