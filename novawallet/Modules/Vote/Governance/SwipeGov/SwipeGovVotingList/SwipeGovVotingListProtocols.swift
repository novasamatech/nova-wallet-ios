protocol SwipeGovVotingListViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: SwipeGovVotingListViewModel)
    func didChangeViewModel(
        _ viewModel: SwipeGovVotingListViewModel,
        byRemovingItemWith referendumId: ReferendumIdLocal
    )
}

protocol SwipeGovVotingListPresenterProtocol: AnyObject {
    func setup()
    func removeItem(with referendumId: ReferendumIdLocal)
    func selectVoting(for referendumId: ReferendumIdLocal)
}

protocol SwipeGovVotingListInteractorInputProtocol: AnyObject {}

protocol SwipeGovVotingListInteractorOutputProtocol: AnyObject {}

protocol SwipeGovVotingListWireframeProtocol: AnyObject {}
