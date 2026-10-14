import Foundation

struct SubtensorValidatorFiltersViewModel {
    let selectedSort: SubtensorValidatorSort
    let canReset: Bool
    let canApply: Bool
}

protocol SubtensorValidatorFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: SubtensorValidatorFiltersViewModel)
}

protocol ValidatorFiltersPresenterProtocol: AnyObject {
    func setup()
    func selectSort(_ sort: SubtensorValidatorSort)
    func setHidesUnusualApy(_ value: Bool)
    func reset()
    func apply()
}

protocol ValidatorFiltersInteractorProtocol {
    func supported(_ filters: SubtensorValidatorFilters) -> SubtensorValidatorFilters
}

protocol ValidatorFiltersWireframeProtocol {
    func complete(from view: SubtensorValidatorFiltersViewProtocol?)
}
