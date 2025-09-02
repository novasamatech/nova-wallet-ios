import Foundation
import Foundation_iOS
import Keystore_iOS

struct ParaStkRedeemViewFactory {
    static func createView(for state: ParachainStakingSharedStateProtocol) -> CollatorStakingRedeemViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let interactor = createInteractor(from: state),
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let wireframe = ParaStkRedeemWireframe()

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
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

        let view = CollatorStakingRedeemViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedStateProtocol
    ) -> ParaStkRedeemInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

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
