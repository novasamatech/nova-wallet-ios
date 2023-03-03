import Foundation
import SoraFoundation
import RobinHood

struct GovernanceDelegateSearchViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegates: [AccountAddress: GovernanceDelegateLocal]
    ) -> GovernanceDelegateSearchViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let chain = state.settings.value?.chain else {
            return nil
        }

        let viewModelFactory = GovernanceDelegateViewModelFactory(
            votesDisplayFactory: ReferendumDisplayStringFactory(),
            addressViewModelFactory: DisplayAddressViewModelFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays
        )

        let wireframe = GovernanceDelegateSearchWireframe(state: state)

        let presenter = GovernanceDelegateSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            initDelegates: delegates,
            chain: chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = GovernanceDelegateSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for state: GovernanceSharedState) -> GovernanceDelegateSearchInteractor? {
        guard let settings = state.settings.value else {
            return nil
        }

        let chain = settings.chain
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService,
            let delegateListOperationFactory = state.createOffchainDelegateListFactory(for: settings) else {
            return nil
        }

        let metadataUrl = GovernanceDelegateMetadataFactory().createUrl(for: chain)
        let metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]> =
            JsonDataProviderFactory.shared.getJson(for: metadataUrl)

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: state.requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let blockTimeOperationFactory = BlockTimeOperationFactory(chain: chain)

        return .init(
            delegateListOperationFactory: delegateListOperationFactory,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            connection: connection,
            runtimeService: runtimeService,
            metadataProvider: metadataProvider,
            identityOperationFactory: identityOperationFactory,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeOperationFactory,
            chain: chain,
            operationQueue: state.operationQueue
        )
    }
}
