import Foundation
import SubstrateSdk
import SoraFoundation

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
            chain: chain,
            state: state
        ) else {
            return nil
        }

        let wireframe = DelegationListWireframe()
        let localizationManager = LocalizationManager.shared
        let referendumDisplayStringFactory = ReferendumDisplayStringFactory(
            formatterFactory: AssetBalanceFormatterFactory()
        )
        let stringViewModelFactory = DelegationsDisplayStringFactory(
            referendumDisplayStringFactory: referendumDisplayStringFactory)

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
        chain: ChainModel,
        state _: GovernanceSharedState
    ) -> DelegationListInteractor? {
        guard let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
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

        let subquery = SubqueryDelegationsOperationFactory(url: delegationApi.url)

        let delegationsLocalWrapperFactoryProtocol = GovernanceDelegationsLocalWrapperFactory(
            operationFactory: subquery,
            identityOperationFactory: identityOperationFactory
        )
        return DelegationListInteractor(
            accountAddress: accountAddress,
            chain: chain,
            connection: connection,
            runtimeService: runtimeProvider,
            delegationsLocalWrapperFactoryProtocol: delegationsLocalWrapperFactoryProtocol,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
