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

protocol StakingTypeInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingTypeInteractorOutputProtocol: AnyObject {
    func didReceive(nominationPoolRestrictions: RelaychainStakingRestrictions)
    func didReceive(directStakingRestrictions: RelaychainStakingRestrictions)
    func didReceive(assetBalance: AssetBalance)
}

protocol StakingTypeWireframeProtocol: AlertPresentable {}
