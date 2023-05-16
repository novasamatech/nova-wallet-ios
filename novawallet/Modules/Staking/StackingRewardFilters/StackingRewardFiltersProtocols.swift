protocol StakingRewardFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: StakingRewardFiltersPeriod)
}

protocol StakingRewardFiltersPresenterProtocol: AnyObject {
    func setup()
    func save(_ period: StakingRewardFiltersPeriod)
}

protocol StakingRewardFiltersInteractorInputProtocol: AnyObject {}

protocol StakingRewardFiltersInteractorOutputProtocol: AnyObject {}

protocol StakingRewardFiltersWireframeProtocol: AnyObject {
    func close(view: StakingRewardFiltersViewProtocol?)
}
