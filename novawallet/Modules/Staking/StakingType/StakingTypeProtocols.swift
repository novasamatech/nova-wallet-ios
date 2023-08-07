protocol StakingTypeViewProtocol: ControllerBackedProtocol {
    func didReceivePoolBanner(viewModel: PoolStakingTypeViewModel)
    func didReceiveDirectStakingBanner(viewModel: DirectStakingTypeViewModel, available: Bool)
    func didReceive(stakingTypeSelection: StakingTypeSelection)
}

protocol StakingTypePresenterProtocol: AnyObject {
    func setup()
    func selectNominators()
    func selectNominationPool()
    func change(stakingTypeSelection: StakingTypeSelection)
}

protocol StakingTypeInteractorInputProtocol: AnyObject {}

protocol StakingTypeInteractorOutputProtocol: AnyObject {}

protocol StakingTypeWireframeProtocol: AlertPresentable {}
