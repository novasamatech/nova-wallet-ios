import Foundation_iOS

protocol ValidatorListFilterWireframeProtocol {
    func close(_ view: ControllerBackedProtocol?)
}

protocol ValidatorListFilterViewProtocol: ControllerBackedProtocol {
    func didUpdateViewModel(_ viewModel: ValidatorListFilterViewModel)
}

protocol ValidatorListFilterPresenterProtocol {
    var view: ValidatorListFilterViewProtocol? { get set }

    func setup()

    func toggleFilter(for viewModel: ValidatorListFilterCellViewModel<ValidatorListFilterRow>)
    func selectSorting(for viewModel: ValidatorListFilterCellViewModel<ValidatorListSortRow>)
    func applyFilter()
    func resetFilter()
}

protocol ValidatorListFilterDelegate: AnyObject {
    func didUpdate(_ filter: CustomValidatorListFilter)
}
