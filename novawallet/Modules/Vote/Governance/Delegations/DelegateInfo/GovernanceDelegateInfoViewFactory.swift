import Foundation
import SubstrateSdk
import Foundation_iOS

struct GovernanceDelegateInfoViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegate: GovernanceDelegateLocal
    ) -> GovernanceDelegateInfoViewProtocol? {
        guard
            let interactor = createInteractor(for: state, delegate: delegate),
            let chain = state.settings.value?.chain,
            let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let wireframe = GovernanceDelegateInfoWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()

        let governanceDelegateInfoViewModelFactory = GovernanceDelegateInfoViewModelFactory(
            stringDisplayFactory: referendumDisplayStringFactory
        )

        let presenter = GovernanceDelegateInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            accountManagementFilter: AccountManagementFilter(),
            wallet: wallet,
            initDelegate: delegate,
            infoViewModelFactory: governanceDelegateInfoViewModelFactory,
            identityViewModelFactory: IdentityViewModelFactory(),
            tracksViewModelFactory: GovernanceTrackViewModelFactory(),
            votesViewModelFactory: referendumDisplayStringFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = GovernanceDelegateInfoViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        delegate: GovernanceDelegateLocal
    ) -> GovernanceDelegateInfoInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chain = state.settings.value?.chain,
            let delegateAccountId = try? delegate.stats.address.toAccountId(),
            let statsUrl = chain.externalApis?.governanceDelegations()?.first?.url,
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let timelineService = state.createChainTimelineFacade(),
            let referendumsOperationFactory = state.referendumsOperationFactory,
            let subscriptionFactory = state.subscriptionFactory else {
            return nil
        }

        let selectedAccountId = SelectedWalletSettings.shared.value?.fetch(for: chain.accountRequest())?.accountId

        let statsOperationFactory = SubqueryDelegateStatsOperationFactory(url: statsUrl)

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: state.requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let blockTimeOperationFactory = BlockTimeOperationFactory(chain: chain)

        return .init(
            selectedAccountId: selectedAccountId,
            delegate: delegateAccountId,
            chain: chain,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            referendumOperationFactory: referendumsOperationFactory,
            subscriptionFactory: subscriptionFactory,
            detailsOperationFactory: statsOperationFactory,
            runtimeService: runtimeProvider,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            identityProxyFactory: identityProxyFactory,
            timelineService: timelineService,
            govJsonProviderFactory: JsonDataProviderFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
