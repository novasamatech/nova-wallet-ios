import Foundation

protocol CollatorStkYourCollatorsViewProtocol: ControllerBackedProtocol {
    func reload(state: ParaStkYourCollatorsState)
}

protocol CollatorStkYourCollatorsPresenterProtocol: AnyObject {
    func setup()
    func retry()
    func manageCollators()
    func selectCollator(viewModel: CollatorSelectionViewModel)
}
