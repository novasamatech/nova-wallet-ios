protocol DelegationListViewProtocol: AnyObject {}

protocol DelegationListPresenterProtocol: AnyObject {
    func setup()
}

protocol DelegationListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol DelegationListInteractorOutputProtocol: AnyObject {
    func didReceive(delegations: [AccountAddress: [GovernanceOffchainDelegation]])
    func didReceive(error: DelegationListError)
}

protocol DelegationListWireframeProtocol: AnyObject {}

enum DelegationListError: Error {
    case fetchFailed(Error)
}
