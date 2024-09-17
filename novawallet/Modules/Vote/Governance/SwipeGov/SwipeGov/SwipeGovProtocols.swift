import Operation_iOS

protocol SwipeGovViewProtocol: ControllerBackedProtocol {
    func updateCardsStack(with viewModel: CardsZStackViewModel)
    func skipCard()
    func updateVotingList(with viewModel: VotingListWidgetViewModel)
    func updateCardsCounter(with text: String)
}

protocol SwipeGovPresenterProtocol: AnyObject {
    func setup()
    func actionBack()
    func actionSettings()
    func actionVotingList()
}

protocol SwipeGovInteractorInputProtocol: AnyObject {
    func setup()
    func addVoting(
        with result: VoteResult,
        for referendumId: ReferendumIdLocal
    )
}

protocol SwipeGovInteractorOutputProtocol: AnyObject {
    func didReceive(_ modelBuilderResult: SwipeGovModelBuilder.Result)
    func didReceive(_ votingPower: VotingPowerLocal)
    func didReceive(_ error: Error)
}

protocol SwipeGovWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func showVotingList(
        from view: ControllerBackedProtocol?,
        metaId: MetaAccountModel.Id
    )
    func showVoteSetup(
        from view: ControllerBackedProtocol?,
        initData: ReferendumVotingInitData
    )
    func showReferendumDetails(
        from view: ControllerBackedProtocol?,
        initData: ReferendumDetailsInitData
    )
    func back(from view: ControllerBackedProtocol?)
}
