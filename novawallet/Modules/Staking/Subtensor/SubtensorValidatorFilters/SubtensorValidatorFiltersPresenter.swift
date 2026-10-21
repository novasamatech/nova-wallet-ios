import Foundation

final class SubtensorValidatorFiltersPresenter: SubtensorValidatorFiltersPresenterProtocol {
    weak var view: SubtensorValidatorFiltersViewProtocol?
    weak var delegate: SubtensorValidatorFiltersDelegate?
    private let applied: SubtensorValidatorFilters
    private var draft: SubtensorValidatorFilters
    private let wireframe: SubtensorValidatorFiltersWireframeProtocol

    init(
        applied: SubtensorValidatorFilters,
        wireframe: SubtensorValidatorFiltersWireframeProtocol,
        delegate: SubtensorValidatorFiltersDelegate
    ) {
        self.applied = applied
        draft = applied
        self.wireframe = wireframe
        self.delegate = delegate
    }

    func setup() { provideViewModel() }

    func selectSort(_ sort: SubtensorValidatorSort) {
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
        guard draft != applied else { return }
        delegate?.didReceiveValidator(filters: draft)
        wireframe.complete(from: view)
    }

    private func provideViewModel() {
        view?.didReceive(SubtensorValidatorFiltersViewModel(
            selectedSort: draft.sort,
            hidesUnusualApy: draft.hidesUnusualApy,
            canReset: draft != SubtensorValidatorFilters(),
            canApply: draft != applied
        ))
    }
}
