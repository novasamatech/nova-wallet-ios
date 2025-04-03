import Foundation
import SubstrateSdk
import Foundation_iOS

struct DelegationListViewFactory {
    static func createView(
        accountAddress: AccountAddress,
        state: GovernanceSharedState
    ) -> VotesViewController? {
        guard let chain = state.settings.value?.chain else {
            return nil
        }

        guard let interactor = createInteractor(
            accountAddress: accountAddress,
            chain: chain
        ) else {
            return nil
        }

        let wireframe = DelegationListWireframe()
        let localizationManager = LocalizationManager.shared
        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()
        let stringViewModelFactory = DelegationsDisplayStringFactory(
            referendumDisplayStringFactory: referendumDisplayStringFactory
        )

        let presenter = DelegationListPresenter(
            interactor: interactor,
            chain: chain,
            stringFactory: stringViewModelFactory,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = VotesViewController(
            presenter: presenter,
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        accountAddress: AccountAddress,
        chain: ChainModel
    ) -> DelegationListInteractor? {
        guard let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

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

        let subquery = SubqueryDelegationsOperationFactory(url: delegationApi.url)

        let delegationsLocalWrapperFactoryProtocol = GovernanceDelegationsLocalWrapperFactory(
            chain: chain,
            operationFactory: subquery,
            identityProxyFactory: identityProxyFactory
        )

        return DelegationListInteractor(
            accountAddress: accountAddress,
            delegationsLocalWrapperFactoryProtocol: delegationsLocalWrapperFactoryProtocol,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
