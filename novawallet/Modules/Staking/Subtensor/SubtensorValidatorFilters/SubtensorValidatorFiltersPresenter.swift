import Foundation

final class SubtensorValidatorFiltersPresenter: ValidatorFiltersPresenterProtocol {
    weak var view: SubtensorValidatorFiltersViewProtocol?
    private let applied: SubtensorValidatorFilters
    private var draft: SubtensorValidatorFilters
    private let wireframe: ValidatorFiltersWireframeProtocol
    private let onApply: (SubtensorValidatorFilters) -> Void
    private var hasApplied = false

    init(
        applied: SubtensorValidatorFilters,
        wireframe: ValidatorFiltersWireframeProtocol,
        onApply: @escaping (SubtensorValidatorFilters) -> Void
    ) {
        self.applied = applied
        draft = applied
        self.wireframe = wireframe
        self.onApply = onApply
    }

    func setup() { provideViewModel() }

    func selectSort(_ sort: SubtensorValidatorSort) {
        guard sort != .apy else { return }
        draft.sort = sort
        provideViewModel()
    }

    func setHidesUnusualApy(_ value: Bool) {
        draft.hidesUnusualApy = value
        provideViewModel()
    }

    func reset() {
        draft = SubtensorValidatorFilters()
        provideViewModel()
    }

    func apply() {
        guard draft != applied, !hasApplied else { return }
        hasApplied = true
        onApply(draft)
        wireframe.complete(from: view)
    }

    private func provideViewModel() {
        view?.didReceive(SubtensorValidatorFiltersViewModel(
            selectedSort: draft.sort,
            hidesUnusualApy: draft.hidesUnusualApy,
            canReset: draft != SubtensorValidatorFilters(),
            canApply: draft != applied && !hasApplied
        ))
    }
}
