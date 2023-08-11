protocol StakingSelectPoolViewProtocol: ControllerBackedProtocol {
    func didReceivePools(viewModels: [StakingSelectPoolViewModel])
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
}

protocol StakingSelectPoolWireframeProtocol: AnyObject {}
