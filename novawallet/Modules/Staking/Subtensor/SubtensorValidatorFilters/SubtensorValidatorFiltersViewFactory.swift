import Foundation_iOS

enum SubtensorValidatorFiltersViewFactory {
    static func createView(
        applied: SubtensorValidatorFilters,
        onApply: @escaping (SubtensorValidatorFilters) -> Void
    ) -> SubtensorValidatorFiltersViewProtocol {
        let presenter = SubtensorValidatorFiltersPresenter(
            applied: applied,
            interactor: SubtensorValidatorFiltersInteractor(),
            wireframe: SubtensorValidatorFiltersWireframe(),
            onApply: onApply
        )
        let view = SubtensorValidatorFiltersViewController(
            presenter: presenter, localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        return view
    }
}
