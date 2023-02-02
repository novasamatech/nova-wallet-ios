import Foundation
import SoraFoundation

struct DelegationListViewFactory {
    static func createView(
        accountAddress: AccountAddress,
        state: GovernanceSharedState
    ) -> VotesViewController? {
        guard
            let chain = state.settings.value?.chain,
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return nil
        }

        let interactor = DelegationListInteractor(
            accountAddress: accountAddress,
            governanceOffchainDelegationsFactory: SubqueryDelegationsOperationFactory(url: delegationApi.url),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
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
            localizationManager: localizationManager
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
}
