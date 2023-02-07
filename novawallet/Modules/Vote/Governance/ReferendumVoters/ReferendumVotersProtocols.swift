protocol ReferendumVotersViewProtocol: ControllerBackedProtocol, VotesViewProtocol {}

protocol ReferendumVotersPresenterProtocol: AnyObject, VotesPresenterProtocol {}

protocol ReferendumVotersInteractorInputProtocol: AnyObject {
    func setup()
    func refreshVoters()
}

protocol ReferendumVotersInteractorOutputProtocol: AnyObject {
    func didReceiveVoters(_ voters: ReferendumVotersModel)
    func didReceiveError(_ error: ReferendumVotersInteractorError)
}

protocol ReferendumVotersWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    AddressOptionsPresentable {}
