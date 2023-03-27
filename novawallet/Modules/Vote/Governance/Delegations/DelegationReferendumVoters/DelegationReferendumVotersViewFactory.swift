import Foundation
import SoraFoundation
import SubstrateSdk

struct DelegationReferendumVotersViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        type: ReferendumVotersType,
        delegationApi: LocalChainExternalApi
    ) -> DelegationReferendumVotersViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let chain = state.settings.value?.chain,
              let connection = chainRegistry.getConnection(for: chain.chainId),
              let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let subquery = SubqueryVotingOperationFactory(url: delegationApi.url)

        let votersLocalWrapperFactory = ReferendumVotersLocalWrapperFactory(
            operationFactory: subquery,
            identityOperationFactory: identityOperationFactory,
            metadataOperationFactory: GovernanceDelegateMetadataFactory()
        )

        let interactor = DelegationReferendumVotersInteractor(
            referendumId: referendum.index,
            votersType: type,
            chain: chain,
            connection: connection,
            runtimeService: runtimeProvider,
            votersLocalWrapperFactory: votersLocalWrapperFactory,
            operationQueue: OperationQueue()
        )
        let wireframe = DelegationReferendumVotersWireframe()
        let referendumDisplayStringFactory = ReferendumDisplayStringFactory(
            formatterFactory: AssetBalanceFormatterFactory()
        )

        let viewModelFactory = DelegationReferendumVotersViewModelFactory(stringFactory: referendumDisplayStringFactory)
        let presenter = DelegationReferendumVotersPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            votersType: type,
            chain: chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = DelegationReferendumVotersViewController(
            presenter: presenter,
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
