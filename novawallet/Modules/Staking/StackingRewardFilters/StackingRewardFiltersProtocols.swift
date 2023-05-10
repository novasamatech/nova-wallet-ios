protocol StackingRewardFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: StackingRewardFiltersViewModel)
}

protocol StackingRewardFiltersPresenterProtocol: AnyObject {
    func setup()
}

protocol StackingRewardFiltersInteractorInputProtocol: AnyObject {}

protocol StackingRewardFiltersInteractorOutputProtocol: AnyObject {}

protocol StackingRewardFiltersWireframeProtocol: AnyObject {}
