import Foundation

struct GovernanceYourDelegationsViewFactory {
    static func createView(for state: GovernanceSharedState) -> GovernanceYourDelegationsViewProtocol? {
        guard let interactor = createInteractor(for: state) else {
            return nil
        }

        let wireframe = GovernanceYourDelegationsWireframe()

        let presenter = GovernanceYourDelegationsPresenter(interactor: interactor, wireframe: wireframe)

        let view = GovernanceYourDelegationsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for state: GovernanceSharedState) -> GovernanceYourDelegationsInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        guard
            let selectedAccountId = SelectedWalletSettings.shared.value?.fetch(for: chain.accountRequest())?.accountId,
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let subscriptionFactory = state.subscriptionFactory,
            let referendumOperationFactory = state.referendumsOperationFactory,
            let offchainOperationFactory = state.createOffchainDelegateListFactory(for: option),
            let blockTimeService = state.blockTimeService
        else {
            return nil
        }

        return .init(
            selectedAccountId: selectedAccountId,
            chain: chain,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            fetchBlockTreshold: GovernanceDelegationConstants.delegateFetchBlockThreshold,
            subscriptionFactory: subscriptionFactory,
            referendumsOperationFactory: state.referendumsOperationFactory,
            offchainOperationFactory: offchainOperationFactory,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: BlockTimeOperationFactory(chain: chain),
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: state.operationQueue
        )
    }
}
