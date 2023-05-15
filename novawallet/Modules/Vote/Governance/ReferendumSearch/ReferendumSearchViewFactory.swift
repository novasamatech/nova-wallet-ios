import Foundation
import SoraFoundation

struct ReferendumSearchViewFactory {
    static func createView(
        state: Observable<ReferendumsState>,
        governanceState: GovernanceSharedState,
        delegate: ReferendumSearchDelegate?
    ) -> ReferendumSearchViewProtocol? {
        let wireframe = ReferendumSearchWireframe(state: governanceState)

        let presenter = ReferendumSearchPresenter(
            wireframe: wireframe,
            delegate: delegate,
            referendumsState: state,
            operationQueue: OperationQueue(),
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
