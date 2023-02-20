import Foundation
import SubstrateSdk
import SoraFoundation

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

        let presenter = GovernanceDelegateInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            accountManagementFilter: AccountManagementFilter(),
            wallet: wallet,
            initDelegate: delegate,
            infoViewModelFactory: GovernanceDelegateInfoViewModelFactory(),
            identityViewModelFactory: IdentityViewModelFactory(),
            tracksViewModelFactory: GovernanceTrackViewModelFactory(),
            votesViewModelFactory: ReferendumDisplayStringFactory(),
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
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService,
            let referendumsOperationFactory = state.referendumsOperationFactory,
            let subscriptionFactory = state.subscriptionFactory else {
            return nil
        }

        let selectedAccountId = SelectedWalletSettings.shared.value?.fetch(for: chain.accountRequest())?.accountId

        let statsOperationFactory = SubqueryDelegateStatsOperationFactory(url: statsUrl)

        let metadataUrl = GovernanceDelegateMetadataFactory().createUrl(for: chain)
        let metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]> =
            JsonDataProviderFactory.shared.getJson(for: metadataUrl)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: storageRequestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let blockTimeOperationFactory = BlockTimeOperationFactory(chain: chain)

        return .init(
            selectedAccountId: selectedAccountId,
            delegate: delegateAccountId,
            chain: chain,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            fetchBlockTreshold: GovernanceDelegationConstants.delegateFetchBlockThreshold,
            referendumOperationFactory: referendumsOperationFactory,
            subscriptionFactory: subscriptionFactory,
            detailsOperationFactory: statsOperationFactory,
            connection: connection,
            runtimeService: runtimeProvider,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            metadataProvider: metadataProvider,
            identityOperationFactory: identityOperationFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
