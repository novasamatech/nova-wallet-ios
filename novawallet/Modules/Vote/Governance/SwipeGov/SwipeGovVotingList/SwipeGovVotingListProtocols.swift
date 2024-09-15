import Operation_iOS

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

protocol SwipeGovVotingListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SwipeGovVotingListInteractorOutputProtocol: AnyObject {
    func didReceive(_ referendumMetadataChanges: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceive(_ votingBasketItems: [VotingBasketItemLocal])
    func didReceive(_ assetBalance: AssetBalance?)
    func didReceive(_ error: Error)
}

protocol SwipeGovVotingListWireframeProtocol: AnyObject {}
