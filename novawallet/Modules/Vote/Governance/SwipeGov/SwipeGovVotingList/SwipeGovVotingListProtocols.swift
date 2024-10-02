import Operation_iOS

protocol SwipeGovVotingListViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModel: SwipeGovVotingListViewModel)
}

protocol SwipeGovVotingListPresenterProtocol: AnyObject {
    func setup()
    func removeItem(with referendumId: ReferendumIdLocal)
    func selectVoting(for referendumId: ReferendumIdLocal)
    func vote()
    func becomeActive()
    func becomeInactive()
}

protocol SwipeGovVotingListInteractorInputProtocol: AnyObject {
    func setup()
    func removeItem(with identifier: String)
    func subscribeMetadata()
    func subscribeBalance()
    func subscribeVotingItems()
    func becomeActive()
    func becomeInactive()
}

protocol SwipeGovVotingListInteractorOutputProtocol: AnyObject {
    func didReceive(_ referendumMetadataChanges: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceive(_ votingBasketChanges: [DataProviderChange<VotingBasketItemLocal>])
    func didReceive(_ assetBalance: AssetBalance?)
    func didReceive(_ error: SwipeGovVotingListInteractorError)
}

protocol SwipeGovVotingListWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    CommonRetryable,
    SwipeGovAlertPresentable {
    func close(view: ControllerBackedProtocol?)

    func showReferendumDetails(
        from view: ControllerBackedProtocol?,
        initData: ReferendumDetailsInitData
    )

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        initData: ReferendumVotingInitData
    )
}
