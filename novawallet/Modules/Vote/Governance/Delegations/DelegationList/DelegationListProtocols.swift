protocol DelegationListViewProtocol: AnyObject {}

protocol DelegationListPresenterProtocol: VotesPresenterProtocol {
    func setup()
}

protocol DelegationListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol DelegationListInteractorOutputProtocol: AnyObject {
    func didReceive(delegations: GovernanceOffchainDelegationsLocal)
    func didReceive(error: DelegationListError)
}

protocol DelegationListWireframeProtocol: AddressOptionsPresentable {}

enum DelegationListError: Error {
    case fetchFailed(Error)
}
