import Foundation
import Foundation_iOS
import SubstrateSdk

struct DelegationReferendumVotersViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        type: ReferendumVotersType,
        delegationApi: LocalChainExternalApi
    ) -> DelegationReferendumVotersViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let chain = state.settings.value?.chain else {
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

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let subquery = SubqueryVotingOperationFactory(url: delegationApi.url)

        let votersLocalWrapperFactory = ReferendumVotersLocalWrapperFactory(
            chain: chain,
            operationFactory: subquery,
            identityProxyFactory: identityProxyFactory,
            metadataOperationFactory: GovernanceDelegateMetadataFactory()
        )

        let interactor = DelegationReferendumVotersInteractor(
            referendumId: referendum.index,
            votersType: type,
            votersLocalWrapperFactory: votersLocalWrapperFactory,
            operationQueue: OperationQueue()
        )
        let wireframe = DelegationReferendumVotersWireframe()
        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()
        let viewModelFactory = DelegationReferendumVotersViewModelFactory(
            stringFactory: referendumDisplayStringFactory
        )
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
