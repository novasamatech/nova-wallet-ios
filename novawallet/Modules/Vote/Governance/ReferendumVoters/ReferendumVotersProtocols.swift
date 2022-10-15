protocol ReferendumVotersViewProtocol: ControllerBackedProtocol {
    func didReceiveViewModels(_ viewModels: LoadableViewModelState<[ReferendumVotersViewModel]>)
}

protocol ReferendumVotersPresenterProtocol: AnyObject {
    func setup()

    func selectVoter(at index: Int)
}

protocol ReferendumVotersInteractorInputProtocol: AnyObject {
    func setup()
    func refreshVoters()
}

protocol ReferendumVotersInteractorOutputProtocol: AnyObject {
    func didReceiveVoters(_ voters: ReferendumVotersModel)
    func didReceiveError(_ error: ReferendumVotersInteractorError)
}

protocol ReferendumVotersWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {}
