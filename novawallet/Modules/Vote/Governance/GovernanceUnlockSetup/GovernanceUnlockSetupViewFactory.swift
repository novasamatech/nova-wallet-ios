import Foundation
import SoraFoundation

struct GovernanceUnlockSetupViewFactory {
    static func createView(for state: GovernanceSharedState) -> GovernanceUnlockSetupViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let assetInfo = state.settings.value?.utilityAssetDisplayInfo(),
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
            let chain = state.settings.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest()),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId),
            let subscriptionFactory = state.subscriptionFactory,
            let blockTimeService = state.blockTimeService else {
            return nil
        }

        let lockStateFactory = Gov2LockStateFactory(
            requestFactory: state.requestFactory,
            unlocksCalculator: Gov2UnlocksCalculator()
        )

        return .init(
            chain: chain,
            selectedAccount: selectedAccount,
            subscriptionFactory: subscriptionFactory,
            lockStateFactory: lockStateFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager
        )
    }
}
