import Foundation

protocol StaticValidatorListViewProtocol: ControllerBackedProtocol {
    func didReload(_ viewModel: SelectedValidatorListViewModel)
}

protocol StaticValidatorListPresenterProtocol: AnyObject {
    func setup()
    func didSelectValidator(at index: Int)
}

protocol StaticValidatorListWireframeProtocol: AnyObject {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )
}
