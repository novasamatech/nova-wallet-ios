import Foundation_iOS

enum SubtensorValidatorFiltersViewFactory {
    static func createView(
        applied: SubtensorValidatorFilters,
        delegate: SubtensorValidatorFiltersDelegate
    ) -> SubtensorValidatorFiltersViewProtocol {
        let presenter = SubtensorValidatorFiltersPresenter(
            applied: applied,
            wireframe: SubtensorValidatorFiltersWireframe(),
            delegate: delegate
        )
        let view = SubtensorValidatorFiltersViewController(
            presenter: presenter, localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        return view
    }
}
