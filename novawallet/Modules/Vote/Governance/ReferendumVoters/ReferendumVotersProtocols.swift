protocol ReferendumVotersViewProtocol: AnyObject {}

protocol ReferendumVotersPresenterProtocol: AnyObject {
    func setup()
}

protocol ReferendumVotersInteractorInputProtocol: AnyObject {
    func setup()
    func refreshVoters()
}

protocol ReferendumVotersInteractorOutputProtocol: AnyObject {
    func didReceiveVoters(_ voters: ReferendumVotersModel)
    func didReceiveError(_ error: ReferendumsInteractorError)
}

protocol ReferendumVotersWireframeProtocol: AnyObject {}
