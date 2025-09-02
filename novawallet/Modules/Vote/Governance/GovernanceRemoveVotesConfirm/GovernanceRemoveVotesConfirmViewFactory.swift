import Foundation
import Foundation_iOS
import Operation_iOS

struct GovernanceRemoveVotesConfirmViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        tracks: [GovernanceTrackInfoLocal]
    ) -> GovernanceRemoveVotesConfirmViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let option = state.settings.value,
            let assetDisplayInfo = option.chain.utilityAssetDisplayInfo(),
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: option.chain.accountRequest()
            ),
            let interactor = createInteractor(for: state, currencyManager: currencyManager)
        else {
            return nil
        }

        let chain = option.chain

        let wireframe = GovRemoveVotesConfirmWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let dataValidatingFactory = GovernanceValidatorFactory.createFromPresentable(wireframe, govType: option.type)

        let presenter = GovernanceRemoveVotesConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            tracks: tracks,
            selectedAccount: selectedAccount,
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory,
            trackViewModelFactory: GovernanceTrackViewModelFactory(),
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

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return GovernanceRemoveVotesConfirmInteractor(
            selectedAccount: selectedAccount.chainAccount,
            chain: chain,
            chainRegistry: state.chainRegistry,
            subscriptionFactory: subscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            extrinsicFactory: extrinsicFactory,
            signer: signer,
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
    }
}
