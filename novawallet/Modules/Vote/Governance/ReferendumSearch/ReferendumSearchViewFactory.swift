import Foundation
import Foundation_iOS

struct ReferendumSearchViewFactory {
    static func createView(
        state: Observable<ReferendumsViewState>,
        governanceState: GovernanceSharedState,
        delegate: ReferendumSearchDelegate?
    ) -> ReferendumSearchViewProtocol? {
        let wireframe = ReferendumSearchWireframe(state: governanceState)

        let presenter = ReferendumSearchPresenter(
            wireframe: wireframe,
            delegate: delegate,
            referendumsState: state,
            searchOperationFactory: ReferendumsSearchOperationFactory(),
            operationQueue: OperationQueue(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = ReferendumSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
