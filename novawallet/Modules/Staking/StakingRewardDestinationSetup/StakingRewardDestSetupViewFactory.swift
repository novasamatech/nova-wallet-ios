import Foundation_iOS
import Keystore_iOS
import Operation_iOS

struct StakingRewardDestSetupViewFactory {
    static func createView(for state: RelaychainStakingSharedStateProtocol) -> StakingRewardDestSetupViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let interactor = createInteractor(state: state),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = StakingRewardDestSetupWireframe(state: state)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let assetInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

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
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingRewardDestSetupInteractor? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let rewardCalculationService = state.rewardCalculatorService

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let storageFacade = UserDataStorageFacade.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)

        return StakingRewardDestSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.localSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicServiceFactory: extrinsicServiceFactory,
            calculatorService: rewardCalculationService,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy(),
            currencyManager: currencyManager
        )
    }
}
