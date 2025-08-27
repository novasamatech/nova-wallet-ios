import Foundation
import Foundation_iOS

struct StakingRemoveProxyViewFactory {
    static func createView(
        state: RelaychainStakingSharedStateProtocol,
        proxyAccount: Proxy.Account
    ) -> StakingConfirmProxyViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard let currencyManager = CurrencyManager.shared,
              let wallet = SelectedWalletSettings.shared.value,
              let interactor = createInteractor(
                  state: state,
                  wallet: wallet,
                  proxyAccount: proxyAccount
              ) else {
            return nil
        }

        let wireframe = StakingConfirmProxyWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let dataValidatingFactory = ProxyDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )

        let presenter = StakingRemoveProxyPresenter(
            chainAsset: chainAsset,
            wallet: wallet,
            proxyAccount: proxyAccount,
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidatingFactory,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            networkViewModelFactory: NetworkViewModelFactory(),
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = StakingConfirmProxyViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            title: .init {
                R.string.localizable.stakingProxyManagementRevokeAccess(
                    preferredLanguages: $0.rLanguages
                )
            }
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        state: RelaychainStakingSharedStateProtocol,
        wallet: MetaAccountModel,
        proxyAccount: Proxy.Account
    ) -> StakingRemoveProxyInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = wallet.fetch(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount, chain: chainAsset.chain)

        let accountProviderFactory = AccountProviderFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: wallet.metaId,
            accountResponse: selectedAccount
        )

        return StakingRemoveProxyInteractor(
            proxyAccount: proxyAccount,
            signingWrapper: signingWrapper,
            chainAsset: state.stakingOption.chainAsset,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            accountProviderFactory: accountProviderFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            callFactory: SubstrateCallFactory(),
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            selectedAccount: selectedAccount,
            currencyManager: currencyManager
        )
    }
}
