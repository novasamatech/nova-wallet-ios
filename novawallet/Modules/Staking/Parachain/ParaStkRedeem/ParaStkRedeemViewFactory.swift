import Foundation
import SoraFoundation
import SoraKeystore

struct ParaStkRedeemViewFactory {
    static func createView(for state: ParachainStakingSharedState) -> ParaStkRedeemViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(from: state),
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let wireframe = ParaStkRedeemWireframe()

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)

        let dataValidationFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo
        )

        let presenter = ParaStkRedeemPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkRedeemViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedState
    ) -> ParaStkRedeemInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: selectedAccount.chainAccount.accountId,
            chain: chainAsset.chain,
            cryptoType: selectedAccount.chainAccount.cryptoType,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return ParaStkRedeemInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            signer: signer,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            currencyManager: currencyManager
        )
    }
}
