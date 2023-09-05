protocol StakingSelectPoolViewProtocol: ControllerBackedProtocol {
    func didReceivePools(state: LoadableViewModelState<[StakingSelectPoolViewModel]>)
    func didReceivePoolUpdate(viewModel: StakingSelectPoolViewModel)
    func didReceiveRecommendedButton(viewModel: ButtonViewModel)
}

protocol StakingSelectPoolPresenterProtocol: AnyObject {
    func setup()
    func selectPool(poolId: NominationPools.PoolId)
    func showPoolInfo(poolId: NominationPools.PoolId)
    func selectRecommended()
    func search()
}

protocol StakingSelectPoolInteractorInputProtocol: AnyObject {
    func setup()
    func refreshPools()
    func refreshRecommendation()
}

protocol StakingSelectPoolInteractorOutputProtocol: AnyObject {
    func didReceive(poolStats: [NominationPools.PoolStats])
    func didReceive(recommendedPool: NominationPools.SelectedPool)
    func didReceive(error: StakingSelectPoolError)
}

protocol StakingSelectPoolWireframeProtocol: AnyObject, AddressOptionsPresentable, CommonRetryable, AlertPresentable {
    func complete(from view: ControllerBackedProtocol?)

    func showSearch(
        from view: ControllerBackedProtocol?,
        delegate: StakingSelectPoolDelegate,
        selectedPoolId: NominationPools.PoolId?
    )
}

enum StakingSelectPoolError: Error {
    case poolStats(Error)
    case recommendation(Error)
}
