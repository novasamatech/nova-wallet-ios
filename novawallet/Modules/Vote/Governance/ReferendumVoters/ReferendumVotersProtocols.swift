protocol ReferendumVotersViewProtocol: ControllerBackedProtocol {
    func didReceiveViewModels(_ viewModels: LoadableViewModelState<[ReferendumVotersViewModel]>)
    func didReceive(title: LocalizableResource<String>)
    func didReceiveEmptyView(title: LocalizableResource<String>)
}

protocol ReferendumVotersPresenterProtocol: AnyObject {
    func setup()

    func selectVoter(for viewModel: ReferendumVotersViewModel)
}

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
