import Foundation
import Foundation_iOS

struct ReferendumsFiltersViewFactory {
    static func createView(
        delegate: ReferendumsFiltersDelegate?,
        filter: ReferendumsFilter
    ) -> ReferendumsFiltersViewProtocol? {
        let wireframe = ReferendumsFiltersWireframe()
        let localizationManager = LocalizationManager.shared

        let presenter = ReferendumsFiltersPresenter(
            wireframe: wireframe,
            initialFilter: filter,
            delegate: delegate
        )

        let view = ReferendumsFiltersViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
