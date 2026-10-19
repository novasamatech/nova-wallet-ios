import Foundation

struct SubtensorValidatorFiltersViewModel {
    let selectedSort: SubtensorValidatorSort
    let hidesUnusualApy: Bool
    let canReset: Bool
    let canApply: Bool
}

protocol SubtensorValidatorFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: SubtensorValidatorFiltersViewModel)
}

protocol SubtensorValidatorFiltersPresenterProtocol: AnyObject {
    func setup()
    func selectSort(_ sort: SubtensorValidatorSort)
    func setHidesUnusualApy(_ value: Bool)
    func reset()
    func apply()
}

protocol SubtensorValidatorFiltersWireframeProtocol {
    func complete(from view: SubtensorValidatorFiltersViewProtocol?)
}
