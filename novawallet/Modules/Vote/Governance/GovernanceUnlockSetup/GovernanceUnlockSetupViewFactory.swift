import Foundation
import Foundation_iOS

struct GovernanceUnlockSetupViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        initData: GovernanceUnlockInitData
    ) -> GovernanceUnlockSetupViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let assetInfo = state.settings.value?.chain.utilityAssetDisplayInfo(),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = GovernanceUnlockSetupWireframe(state: state)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let localizationManager = LocalizationManager.shared

        let presenter = GovernanceUnlockSetupPresenter(
            initData: initData,
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            assetDisplayInfo: assetInfo,
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )

        let view = GovernanceUnlockSetupViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for state: GovernanceSharedState) -> GovernanceUnlockSetupInteractor? {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let chain = state.settings.value?.chain,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest()),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId),
            let subscriptionFactory = state.subscriptionFactory,
            let lockStateFactory = state.locksOperationFactory,
            let blockTimeService = state.blockTimeService,
            let blockTimeFactory = state.createBlockTimeOperationFactory() else {
            return nil
        }

        return .init(
            chain: chain,
            selectedAccount: selectedAccount,
            subscriptionFactory: subscriptionFactory,
            lockStateFactory: lockStateFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager
        )
    }
}
