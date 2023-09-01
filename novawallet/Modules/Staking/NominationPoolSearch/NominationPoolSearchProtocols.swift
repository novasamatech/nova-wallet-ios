protocol NominationPoolSearchViewProtocol: ControllerBackedProtocol {
    func didReceivePools(state: GenericViewState<[StakingSelectPoolViewModel]>)
}

protocol NominationPoolSearchPresenterProtocol: TableSearchPresenterProtocol {
    func selectPool(poolId: NominationPools.PoolId)
    func showPoolInfo(poolId: NominationPools.PoolId)
}

protocol NominationPoolSearchInteractorInputProtocol: AnyObject {
    func setup()
    func search(for text: String)
    func refetchPools()
    func remakeSubscriptions()
}

protocol NominationPoolSearchInteractorOutputProtocol: AnyObject {
    func didReceive(poolStats: [NominationPools.PoolStats])
    func didStartSearch(for text: String)
    func didReceive(error: NominationPoolSearchError)
}

protocol NominationPoolSearchWireframeProtocol: AddressOptionsPresentable, AlertPresentable, CommonRetryable {
    func complete(from view: ControllerBackedProtocol?)
}

enum NominationPoolSearchError: Error {
    case pools(Error)
    case subscription(Error)
    case emptySearchResults
}
