protocol StackingRewardFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: StackingRewardFiltersPeriod)
}

protocol StackingRewardFiltersPresenterProtocol: AnyObject {
    func setup()
    func save(_ period: StackingRewardFiltersPeriod)
}

protocol StackingRewardFiltersInteractorInputProtocol: AnyObject {}

protocol StackingRewardFiltersInteractorOutputProtocol: AnyObject {}

protocol StackingRewardFiltersWireframeProtocol: AnyObject {
    func close(view: StackingRewardFiltersViewProtocol?)
}
