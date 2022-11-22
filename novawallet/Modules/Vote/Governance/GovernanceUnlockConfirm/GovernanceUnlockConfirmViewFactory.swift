import Foundation
import RobinHood
import SoraFoundation

struct GovernanceUnlockConfirmViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        initData: GovernanceUnlockConfirmInitData
    ) -> GovernanceUnlockConfirmViewProtocol? {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let chain = state.settings.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest()),
            let interactor = createInteractor(for: state, chain: chain, selectedAccount: selectedAccount),
            let assetInfo = chain.utilityAssetDisplayInfo(),
            let currencyManager = CurrencyManager.shared,
            let votingLockId = state.governanceId(for: chain)
        else {
            return nil
        }

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

        let dataValidatingFactory = GovernanceValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

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
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse
    ) -> GovernanceUnlockConfirmInteractor? {
        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId),
            let subscriptionFactory = state.subscriptionFactory,
            let lockStateFactory = state.locksOperationFactory,
            let extrinsicFactory = state.createExtrinsicFactory(for: chain),
            let blockTimeService = state.blockTimeService,
            let blockTimeFactory = state.createBlockTimeOperationFactory(),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return .init(
            chain: chain,
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
