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
    func vote()
}

protocol SwipeGovVotingListInteractorInputProtocol: AnyObject {
    func setup()
    func removeItem(with identifier: String)
    func subscribeMetadata()
    func subscribeBalance()
    func subscribeVotingItems()
}

protocol SwipeGovVotingListInteractorOutputProtocol: AnyObject {
    func didReceive(_ referendumMetadataChanges: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceive(_ votingBasketChanges: [DataProviderChange<VotingBasketItemLocal>])
    func didReceive(_ assetBalance: AssetBalance?)
    func didReceiveUnavailableItems()
    func didReceive(_ error: SwipeGovVotingListInteractorError)
}

protocol SwipeGovVotingListWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, SwipeGovAlertPresentable {
    func close(view: ControllerBackedProtocol?)
    func showSetup(
        from view: ControllerBackedProtocol?,
        initData: ReferendumVotingInitData,
        changing invalidItems: [VotingBasketItemLocal]
    )
    func showReferendumDetails(
        from view: ControllerBackedProtocol?,
        initData: ReferendumDetailsInitData
    )
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        initData: ReferendumVotingInitData
    )
}
