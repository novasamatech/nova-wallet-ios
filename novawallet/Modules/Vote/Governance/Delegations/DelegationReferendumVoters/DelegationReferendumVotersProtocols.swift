protocol DelegationReferendumVotersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [DelegationReferendumVotersModel])
    func didReceive(title: String)
}

protocol DelegationReferendumVotersPresenterProtocol: AnyObject {
    func setup()
    func select(address: AccountAddress)
}

protocol DelegationReferendumVotersInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol DelegationReferendumVotersInteractorOutputProtocol: AnyObject {
    func didReceive(error: DelegationReferendumVotersError)
    func didReceive(voters: ReferendumVoterLocals)
}

protocol DelegationReferendumVotersWireframeProtocol:
    AlertPresentable, ErrorPresentable, CommonRetryable, AddressOptionsPresentable {}
