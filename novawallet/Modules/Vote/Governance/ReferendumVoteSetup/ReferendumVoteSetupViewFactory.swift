import Foundation
import SubstrateSdk
import RobinHood
import SoraFoundation

struct ReferendumVoteSetupViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        referendum: ReferendumIdLocal
    ) -> ReferendumVoteSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                referendum: referendum,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = ReferendumVoteSetupWireframe()

        let presenter = ReferendumVoteSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = ReferendumVoteSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        referendum: ReferendumIdLocal,
        currencyManager: CurrencyManagerProtocol
    ) -> ReferendumVoteSetupInteractor? {
        guard
            let chain = state.settings.value,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chain.accountRequest()
            ),
            let subscriptionFactory = state.subscriptionFactory,
            let blockTimeService = state.blockTimeService
        else {
            return nil
        }

        let chainRegistry = state.chainRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let requestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: operationManager)

        let lockStateFactory = Gov2LockStateFactory(requestFactory: requestFactory)

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: operationManager
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        return ReferendumVoteSetupInteractor(
            referendumIndex: referendum,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            blockTimeService: blockTimeService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            extrinsicFactory: Gov2ExtrinsicFactory(),
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }
}
