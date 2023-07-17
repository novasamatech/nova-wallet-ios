protocol StakingRewardFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: StakingRewardFiltersPeriod)
}

protocol StakingRewardFiltersPresenterProtocol: AnyObject {
    func setup()
    func save(_ period: StakingRewardFiltersPeriod)
}

protocol StakingRewardFiltersWireframeProtocol: AnyObject {
    func close(view: StakingRewardFiltersViewProtocol?)
}

protocol StakingRewardFiltersDelegate: AnyObject {
    func stackingRewardFilter(didSelectFilter filter: StakingRewardFiltersPeriod)
}
