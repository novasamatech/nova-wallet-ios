import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

struct StakingRewardDestConfirmViewFactory {
    static func createView(
        for state: StakingSharedState,
        rewardDestination: RewardDestination<AccountItem>
    ) -> StakingRewardDestConfirmViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(state: state) else {
            return nil
        }

        let wireframe = StakingRewardDestConfirmWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let presenter = StakingRewardDestConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            rewardDestination: rewardDestination,
            confirmModelFactory: StakingRewardDestConfirmVMFactory(),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            explorers: chainAsset.chain.explorers,
            logger: Logger.shared
        )

        let view = StakingRewardDestConfirmViewController(
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
    ) -> StakingRewardDestConfirmInteractor? {
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

        return StakingRewardDestConfirmInteractor(
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
