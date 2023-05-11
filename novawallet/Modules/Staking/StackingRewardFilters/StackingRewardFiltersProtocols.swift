protocol StackingRewardFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: StackingRewardFiltersPeriod)
}

protocol StackingRewardFiltersPresenterProtocol: AnyObject {
    func setup()
    func save()
}

protocol StackingRewardFiltersInteractorInputProtocol: AnyObject {}

protocol StackingRewardFiltersInteractorOutputProtocol: AnyObject {}

protocol StackingRewardFiltersWireframeProtocol: AnyObject {}
