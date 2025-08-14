import Foundation
import Foundation_iOS
import Operation_iOS

struct GovernanceDelegateSearchViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegates: [AccountAddress: GovernanceDelegateLocal],
        yourDelegations: [AccountAddress: GovernanceYourDelegationGroup]
    ) -> GovernanceDelegateSearchViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let chain = state.settings.value?.chain else {
            return nil
        }

        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()
        let addressViewModelFactory = DisplayAddressViewModelFactory()
        let quantityFormatter = NumberFormatter.quantity.localizableResource()

        let anyDelegationViewModelFactory = GovernanceDelegateViewModelFactory(
            votesDisplayFactory: referendumDisplayStringFactory,
            addressViewModelFactory: addressViewModelFactory,
            quantityFormatter: quantityFormatter,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays
        )

        let yourDelegationsViewModelFactory = GovYourDelegationsViewModelFactory(
            votesDisplayFactory: referendumDisplayStringFactory,
            addressViewModelFactory: addressViewModelFactory,
            tracksViewModelFactory: GovernanceTrackViewModelFactory(),
            quantityFormatter: quantityFormatter,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays
        )

        let wireframe = GovernanceDelegateSearchWireframe(state: state)

        let presenter = GovernanceDelegateSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            anyDelegationViewModelFactory: anyDelegationViewModelFactory,
            yourDelegationsViewModelFactory: yourDelegationsViewModelFactory,
            initDelegates: delegates,
            initDelegations: yourDelegations,
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
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let timelineService = state.createChainTimelineFacade(),
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

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        return .init(
            delegateListOperationFactory: delegateListOperationFactory,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            runtimeService: runtimeService,
            metadataProvider: metadataProvider,
            identityProxyFactory: identityProxyFactory,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            timelineService: timelineService,
            chain: chain,
            operationQueue: state.operationQueue
        )
    }
}
