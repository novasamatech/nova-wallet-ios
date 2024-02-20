import Foundation
import SoraFoundation

struct StakingConfirmProxyViewFactory {
    static func createView(
        state: RelaychainStakingSharedStateProtocol,
        proxyAddress: AccountAddress
    ) -> StakingConfirmProxyViewProtocol? {
        guard let currencyManager = CurrencyManager.shared,
              let wallet = SelectedWalletSettings.shared.value,
              let interactor = createInteractor(
                  state: state,
                  wallet: wallet,
                  proxyAddress: proxyAddress
              ) else {
            return nil
        }

        let wireframe = StakingConfirmProxyWireframe()

        let chainAsset = state.stakingOption.chainAsset

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

        let presenter = StakingConfirmProxyPresenter(
            chainAsset: chainAsset,
            wallet: wallet,
            proxyAddress: proxyAddress,
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            networkViewModelFactory: NetworkViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        let view = StakingConfirmProxyViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            title: .init {
                R.string.localizable.stakingAddProxyConfirmationTitle(
                    preferredLanguages: $0.rLanguages
                )
            }
        )

        presenter.baseView = view
        interactor.basePresenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        state: RelaychainStakingSharedStateProtocol,
        wallet: MetaAccountModel,
        proxyAddress: AccountAddress
    ) -> StakingConfirmProxyInteractor? {
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
            operationManager: OperationManagerFacade.sharedManager,
            userStorageFacade: UserDataStorageFacade.shared
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

        return StakingConfirmProxyInteractor(
            proxyAccount: proxyAddress,
            signingWrapper: signingWrapper,
            runtimeService: runtimeRegistry,
            sharedState: state,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            accountProviderFactory: accountProviderFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            callFactory: SubstrateCallFactory(),
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            selectedAccount: selectedAccount,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
