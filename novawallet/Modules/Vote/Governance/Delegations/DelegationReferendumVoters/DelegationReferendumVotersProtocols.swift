protocol DelegationReferendumVotersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: LoadableViewModelState<[DelegationReferendumVotersModel]>)
    func didReceive(title: String)
    func didReceiveEmptyView(title: String)
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
