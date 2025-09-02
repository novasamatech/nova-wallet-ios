import Foundation
import Operation_iOS
import Foundation_iOS

struct GovernanceUnlockConfirmViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        initData: GovernanceUnlockConfirmInitData
    ) -> GovernanceUnlockConfirmViewProtocol? {
        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        guard
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest()),
            let interactor = createInteractor(
                for: state,
                option: option,
                selectedAccount: selectedAccount
            ),
            let assetInfo = chain.utilityAssetDisplayInfo(),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let votingLockId = state.governanceId(for: option)

        let wireframe = GovernanceUnlockConfirmWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let localizationManager = LocalizationManager.shared

        let lockChangeViewModelFactory = ReferendumLockChangeViewModelFactory(
            assetDisplayInfo: assetInfo,
            votingLockId: votingLockId
        )

        let dataValidatingFactory = GovernanceValidatorFactory.createFromPresentable(wireframe, govType: option.type)

        let presenter = GovernanceUnlockConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            selectedAccount: selectedAccount,
            initData: initData,
            balanceViewModelFactory: balanceViewModelFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = GovernanceUnlockConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        option: GovernanceSelectedOption,
        selectedAccount: MetaChainAccountResponse
    ) -> GovernanceUnlockConfirmInteractor? {
        let chain = option.chain

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId),
            let subscriptionFactory = state.subscriptionFactory,
            let lockStateFactory = state.locksOperationFactory,
            let blockTimeService = state.blockTimeService,
            let blockTimeFactory = state.createBlockTimeOperationFactory(),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let extrinsicFactory = state.createExtrinsicFactory(for: option)

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

        return .init(
            chain: chain,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            selectedAccount: selectedAccount,
            subscriptionFactory: subscriptionFactory,
            lockStateFactory: lockStateFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            signer: signer,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
    }
}
