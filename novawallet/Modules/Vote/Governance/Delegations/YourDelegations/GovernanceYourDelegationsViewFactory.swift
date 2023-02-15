import Foundation
import SoraFoundation

struct GovernanceYourDelegationsViewFactory {
    static func createView(for state: GovernanceSharedState) -> GovernanceYourDelegationsViewProtocol? {
        guard let interactor = createInteractor(for: state), let chain = state.settings.value?.chain else {
            return nil
        }

        let wireframe = GovernanceYourDelegationsWireframe(state: state)

        let viewModelFactory = GovYourDelegationsViewModelFactory(
            votesDisplayFactory: ReferendumDisplayStringFactory(),
            addressViewModelFactory: DisplayAddressViewModelFactory(),
            tracksViewModelFactory: GovernanceTrackViewModelFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays
        )

        let presenter = GovernanceYourDelegationsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = GovernanceYourDelegationsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

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
            let referendumsOperationFactory = state.referendumsOperationFactory,
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
            referendumsOperationFactory: referendumsOperationFactory,
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
