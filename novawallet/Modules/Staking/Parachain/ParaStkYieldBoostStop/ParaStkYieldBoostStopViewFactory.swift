import Foundation
import Foundation_iOS

struct ParaStkYieldBoostStopViewFactory {
    static func createView(
        with state: ParachainStakingSharedStateProtocol,
        collatorId: AccountId,
        collatorIdentity: AccountIdentity?
    ) -> ParaStkYieldBoostStopViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let interactor = createInteractor(for: chainAsset, selectedAccount: selectedAccount),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = ParaStkYieldBoostStopWireframe()

        let localizationManager = LocalizationManager.shared

        let dataValidatingFactory = ParaStkYieldBoostValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = ParaStkYieldBoostStopPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            collatorId: collatorId,
            collatorIdentity: collatorIdentity,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkYieldBoostStopViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse
    ) -> ParaStkYieldBoostStopInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chain = chainAsset.chain

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        let commonInteractor = ParaStkYieldBoostCommonInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount.chainAccount,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            yieldBoostProviderFactory: ParaStkYieldBoostProviderFactory.shared,
            currencyManager: currencyManager
        )

        let interactor = ParaStkYieldBoostStopInteractor(
            selectedAccount: selectedAccount.chainAccount,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            signingWrapper: signingWrapper,
            childCommonInteractor: commonInteractor
        )

        commonInteractor.presenter = interactor

        return interactor
    }
}
