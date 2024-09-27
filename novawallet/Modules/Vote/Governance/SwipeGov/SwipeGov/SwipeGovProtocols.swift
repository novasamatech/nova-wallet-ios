import Operation_iOS

protocol SwipeGovViewProtocol: ControllerBackedProtocol {
    func updateCardsStack(with viewModel: CardsZStackViewModel)
    func skipCard()
    func updateVotingList(with viewModel: VotingListWidgetViewModel)
    func updateCardsCounter(with text: String)
    func didReceive(canOpenSettings: Bool)
    func didUpdateVotingPower(for modelId: VoteCardId, voteResult: VoteResult)
}

protocol SwipeGovPresenterProtocol: AnyObject {
    func setup()
    func cardsStackBecameEmpty()
    func actionBack()
    func actionSettings()
    func actionVotingList()
}

protocol SwipeGovInteractorInputProtocol: AnyObject {
    func setup()
    func addVoting(
        with result: VoteResult,
        for referendumId: ReferendumIdLocal,
        votingPower: VotingPowerLocal
    )
}

protocol SwipeGovInteractorOutputProtocol: AnyObject {
    func didReceiveState(_ modelBuilderResult: SwipeGovModelBuilder.Result)
    func didReceiveVotingPower(_ votingPower: VotingPowerLocal)
    func didReceiveBalace(_ assetBalance: AssetBalance?)
}

protocol SwipeGovWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func showVotingList(from view: ControllerBackedProtocol?)

    func showVoteSetup(
        from view: ControllerBackedProtocol?,
        initData: ReferendumVotingInitData,
        newVotingPowerClosure: VotingPowerLocalSetClosure?
    )

    func showReferendumDetails(
        from view: ControllerBackedProtocol?,
        initData: ReferendumDetailsInitData
    )

    func back(from view: ControllerBackedProtocol?)
}
