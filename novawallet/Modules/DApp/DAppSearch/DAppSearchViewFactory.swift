import Foundation
import SoraFoundation

struct DAppSearchViewFactory {
    static func createView(
        with initialQuery: String?,
        delegate: DAppSearchDelegate
    ) -> DAppSearchViewProtocol? {
        let wireframe = DAppSearchWireframe()

        let presenter = DAppSearchPresenter(
            wireframe: wireframe,
            initialQuery: initialQuery,
            delegate: delegate,
            logger: Logger.shared
        )

        let view = DAppSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
