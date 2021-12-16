import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingRewardDestSetupViewFactory {
    static func createView(for state: StakingSharedState) -> StakingRewardDestSetupViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(state: state) else {
            return nil
        }

        let wireframe = StakingRewardDestSetupWireframe(state: state)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let rewardDestinationViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let changeRewardDestViewModelFactory = ChangeRewardDestinationViewModelFactory(
            rewardDestinationViewModelFactory: rewardDestinationViewModelFactory
        )

        let presenter = StakingRewardDestSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            rewardDestViewModelFactory: changeRewardDestViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            applicationConfig: ApplicationConfig.shared,
            assetInfo: assetInfo,
            logger: Logger.shared
        )

        let view = StakingRewardDestSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        state: StakingSharedState
    ) -> StakingRewardDestSetupInteractor? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let storageFacade = UserDataStorageFacade.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)

        return StakingRewardDestSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicServiceFactory: extrinsicServiceFactory,
            calculatorService: state.rewardCalculationService,
            runtimeService: runtimeService,
            operationManager: operationManager,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy()
        )
    }
}
