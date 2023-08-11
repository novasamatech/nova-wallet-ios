protocol StakingSelectPoolViewProtocol: ControllerBackedProtocol {
    func didReceivePools(viewModels: [StakingSelectPoolViewModel])
    func didReceivePoolUpdate(viewModel: StakingSelectPoolViewModel)
}

protocol StakingSelectPoolPresenterProtocol: AnyObject {
    func setup()
    func selectPool(poolId: NominationPools.PoolId)
    func showPoolInfo(poolId: NominationPools.PoolId)
}

protocol StakingSelectPoolInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingSelectPoolInteractorOutputProtocol: AnyObject {
    func didReceive(poolStats: [NominationPools.PoolStats])
    func didReceive(recommendedPool: NominationPools.SelectedPool)
}

protocol StakingSelectPoolWireframeProtocol: AnyObject, AddressOptionsPresentable {
    func complete(from view: ControllerBackedProtocol?)
}
