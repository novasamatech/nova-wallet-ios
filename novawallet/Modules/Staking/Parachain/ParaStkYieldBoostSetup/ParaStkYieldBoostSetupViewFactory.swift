import Foundation
import SubstrateSdk
import SoraFoundation

struct ParaStkYieldBoostSetupViewFactory {
    static func createView(
        with state: ParachainStakingSharedState,
        initData: ParaStkYieldBoostInitState
    ) -> ParaStkYieldBoostSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(with: state, currencyManager: currencyManager),
            let chainAsset = state.settings.value else {
            return nil
        }

        let wireframe = ParaStkYieldBoostSetupWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let accountDetailsViewModelFactory = ParaStkAccountDetailsViewModelFactory(chainAsset: chainAsset)

        let presenter = ParaStkYieldBoostSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initState: initData,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsViewModelFactory,
            chainAsset: chainAsset,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = ParaStkYieldBoostSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        with state: ParachainStakingSharedState,
        currencyManager: CurrencyManagerProtocol
    ) -> ParaStkYieldBoostSetupInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetch(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let rewardService = state.rewardCalculationService else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        return ParaStkYieldBoostSetupInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            rewardService: rewardService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            identityOperationFactory: identityOperationFactory,
            yieldBoostProviderFactory: ParaStkYieldBoostProviderFactory.shared,
            yieldBoostOperationFactory: ParaStkYieldBoostOperationFactory(),
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
