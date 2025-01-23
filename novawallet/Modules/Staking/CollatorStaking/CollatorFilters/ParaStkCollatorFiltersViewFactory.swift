import Foundation
import SoraFoundation

struct ParaStkCollatorFiltersViewFactory {
    static func createView(
        for sorting: CollatorsSortType,
        delegate: ParaStkCollatorFiltersDelegate
    ) -> ParaStkCollatorFiltersViewProtocol? {
        let wireframe = ParaStkCollatorFiltersWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = ParaStkCollatorFiltersPresenter(
            wireframe: wireframe,
            sorting: sorting,
            delegate: delegate,
            localizationManager: localizationManager
        )

        let view = ParaStkCollatorFiltersViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
