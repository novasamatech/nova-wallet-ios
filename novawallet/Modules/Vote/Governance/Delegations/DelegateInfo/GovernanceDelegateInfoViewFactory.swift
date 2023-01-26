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
            let chain = state.settings.value?.chain else {
            return nil
        }

        let wireframe = GovernanceDelegateInfoWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let presenter = GovernanceDelegateInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            initDelegate: delegate,
            infoViewModelFactory: GovernanceDelegateInfoViewModelFactory(),
            identityViewModelFactory: IdentityViewModelFactory(),
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
        guard
            let chain = state.settings.value?.chain,
            let delegateAccountId = try? delegate.stats.address.toAccountId(),
            let statsUrl = chain.externalApis?.governanceDelegations()?.first?.url
        else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService else {
            return nil
        }

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
            delegate: delegateAccountId,
            chain: chain,
            lastVotedDays: GovernanceDelegationConstants.recentVotesInDays,
            fetchBlockTreshold: GovernanceDelegationConstants.delegateFetchBlockThreshold,
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
