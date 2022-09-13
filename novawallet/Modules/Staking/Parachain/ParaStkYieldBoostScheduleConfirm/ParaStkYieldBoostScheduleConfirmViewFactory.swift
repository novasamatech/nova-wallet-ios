import Foundation
import SubstrateSdk
import SoraFoundation

struct ParaStkYieldBoostScheduleConfirmViewFactory {
    static func createView(
        with state: ParachainStakingSharedState,
        confirmModel: ParaStkYieldBoostConfirmModel
    ) -> ParaStkYieldBoostScheduleConfirmViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let interactor = createInteractor(for: chainAsset, selectedAccount: selectedAccount),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = ParaStkYieldBoostScheduleConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let dataValidatingFactory = ParaStkYieldBoostValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = ParaStkYieldBoostScheduleConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            confirmModel: confirmModel,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkYieldBoostScheduleConfirmViewController(
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
    ) -> ParaStkYieldBoostScheduleConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chain = chainAsset.chain

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        let yieldBoostOperationFactory = ParaStkYieldBoostOperationFactory()

        let commonInteractor = ParaStkYieldBoostCommonInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount.chainAccount,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            yieldBoostProviderFactory: ParaStkYieldBoostProviderFactory.shared,
            currencyManager: currencyManager
        )

        let interactor = ParaStkYieldBoostScheduleConfirmInteractor(
            chain: chain,
            selectedAccount: selectedAccount.chainAccount,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: requestFactory,
            yieldBoostOperationFactory: yieldBoostOperationFactory,
            signingWrapper: signingWrapper,
            childCommonInteractor: commonInteractor,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        commonInteractor.presenter = interactor

        return interactor
    }
}
