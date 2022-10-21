import Foundation
import RobinHood
import SubstrateSdk

struct ReferendumVoteConfirmViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        newVote: ReferendumNewVote
    ) -> ReferendumVoteConfirmViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                referendum: newVote.index,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = ReferendumVoteConfirmWireframe()

        let presenter = ReferendumVoteConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = ReferendumVoteConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        referendum: ReferendumIdLocal,
        currencyManager: CurrencyManagerProtocol
    ) -> ReferendumVoteConfirmInteractor? {
        let wallet: MetaAccountModel? = SelectedWalletSettings.shared.value

        guard
            let chain = state.settings.value,
            let selectedAccount = wallet?.fetchMetaChainAccount(for: chain.accountRequest()),
            let subscriptionFactory = state.subscriptionFactory,
            let blockTimeService = state.blockTimeService
        else {
            return nil
        }

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let lockStateFactory = Gov2LockStateFactory(requestFactory: requestFactory)

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: operationManager
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return ReferendumVoteConfirmInteractor(
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
            signer: signer,
            feeProxy: ExtrinsicFeeProxy(),
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }
}
