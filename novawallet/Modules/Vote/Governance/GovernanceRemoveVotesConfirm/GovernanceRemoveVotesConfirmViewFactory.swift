import Foundation
import SoraFoundation
import RobinHood

struct GovernanceRemoveVotesConfirmViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        tracks: [GovernanceTrackInfoLocal]
    ) -> GovernanceRemoveVotesConfirmViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let chain = state.settings.value?.chain,
            let assetDisplayInfo = chain.utilityAssetDisplayInfo(),
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chain.accountRequest()
            ),
            let interactor = createInteractor(for: state, currencyManager: currencyManager)
        else {
            return nil
        }
        let wireframe = GovRemoveVotesConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let dataValidatingFactory = GovernanceValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = GovernanceRemoveVotesConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            tracks: tracks,
            selectedAccount: selectedAccount,
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = GovRemoveVotesConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        currencyManager: CurrencyManagerProtocol
    ) -> GovernanceRemoveVotesConfirmInteractor? {
        let wallet: MetaAccountModel? = SelectedWalletSettings.shared.value

        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        guard
            let selectedAccount = wallet?.fetchMetaChainAccount(for: chain.accountRequest()),
            let subscriptionFactory = state.subscriptionFactory
        else {
            return nil
        }

        let extrinsicFactory = state.createExtrinsicFactory(for: option)

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: operationManager
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return GovernanceRemoveVotesConfirmInteractor(
            selectedAccount: selectedAccount.chainAccount,
            chain: chain,
            subscriptionFactory: subscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            extrinsicFactory: extrinsicFactory,
            signer: signer,
            currencyManager: currencyManager
        )
    }
}
