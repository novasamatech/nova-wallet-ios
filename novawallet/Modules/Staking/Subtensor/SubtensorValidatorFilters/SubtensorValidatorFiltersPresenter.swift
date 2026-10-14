import Foundation

final class SubtensorValidatorFiltersPresenter: ValidatorFiltersPresenterProtocol {
    weak var view: SubtensorValidatorFiltersViewProtocol?
    private let applied: SubtensorValidatorFilters
    private var draft: SubtensorValidatorFilters
    private let interactor: ValidatorFiltersInteractorProtocol
    private let wireframe: ValidatorFiltersWireframeProtocol
    private let onApply: (SubtensorValidatorFilters) -> Void
    private var hasApplied = false

    init(
        applied: SubtensorValidatorFilters,
        interactor: ValidatorFiltersInteractorProtocol,
        wireframe: ValidatorFiltersWireframeProtocol,
        onApply: @escaping (SubtensorValidatorFilters) -> Void
    ) {
        self.applied = interactor.supported(applied)
        draft = interactor.supported(applied)
        self.interactor = interactor
        self.wireframe = wireframe
        self.onApply = onApply
    }

    func setup() { provideViewModel() }

    func selectSort(_ sort: SubtensorValidatorSort) {
        guard sort != .apy else { return }
        draft.sort = sort
        provideViewModel()
    }

    func setHidesUnusualApy(_: Bool) { provideViewModel() }

    func reset() {
        draft = .supportedDefault
        provideViewModel()
    }

    func apply() {
        guard draft != applied, !hasApplied else { return }
        hasApplied = true
        onApply(interactor.supported(draft))
        wireframe.complete(from: view)
    }

    private func provideViewModel() {
        view?.didReceive(SubtensorValidatorFiltersViewModel(
            selectedSort: draft.sort,
            canReset: draft != .supportedDefault,
            canApply: draft != applied && !hasApplied
        ))
    }
}
