import Foundation
import SoraFoundation

struct StakingSetupProxyViewFactory {
    static func createView(state: RelaychainStakingSharedStateProtocol) -> StakingSetupProxyViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        guard let interactor = createInteractor(state: state) else {
            return nil
        }
        let wireframe = StakingSetupProxyWireframe()
        let chainAsset = state.stakingOption.chainAsset

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = StakingSetupProxyPresenter(
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = StakingSetupProxyViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.basePresenter = presenter

        return view
    }

    private static func createInteractor(
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingSetupProxyInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager,
            userStorageFacade: UserDataStorageFacade.shared
        )

        let accountProviderFactory = AccountProviderFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return StakingSetupProxyInteractor(
            runtimeService: runtimeRegistry,
            stakingLocalSubscriptionFactory: state.localSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            accountProviderFactory: accountProviderFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            callFactory: SubstrateCallFactory(),
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicServiceFactory: extrinsicServiceFactory,
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
