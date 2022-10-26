protocol ReferendumDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(votingDetails: ReferendumVotingStatusDetailsView.Model)
    func didReceive(dAppModels: [ReferendumDAppView.Model]?)
    func didReceive(timelineModel: [ReferendumTimelineView.Model]?)
    func didReceive(titleModel: ReferendumDetailsTitleView.Model)
    func didReceive(yourVoteModel: YourVoteRow.Model?)
    func didReceive(requestedAmount: RequestedAmountRow.Model?)
    func didReceive(trackTagsModel: TrackTagsView.Model?)
    func didReceive(activeTimeViewModel: ReferendumInfoView.Model.Time?)
    func didReceive(shouldHideFullDetails: Bool)
}

protocol ReferendumDetailsPresenterProtocol: AnyObject {
    func setup()
    func showProposerDetails()
    func readFullDescription()
    func showAyeVoters()
    func showNayVoters()
    func opeDApp(at index: Int)
    func openFullDetails()
    func vote()
}

protocol ReferendumDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func refreshBlockTime()
    func refreshActionDetails()
    func refreshIdentities()
    func refreshDApps()
    func remakeSubscriptions()
}

protocol ReferendumDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendum(_ referendum: ReferendumLocal)
    func didReceiveActionDetails(_ actionDetails: ReferendumActionLocal)
    func didReceiveAccountVotes(_ votes: ReferendumAccountVoteLocal?)
    func didReceiveMetadata(_ referendumMetadata: ReferendumMetadataLocal?)
    func didReceiveIdentities(_ identities: [AccountAddress: AccountIdentity])
    func didReceivePrice(_ price: PriceData?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveDApps(_ dApps: [GovernanceDApp])
    func didReceiveError(_ error: ReferendumDetailsInteractorError)
}

protocol ReferendumDetailsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    AddressOptionsPresentable {
    func showFullDetails(
        from view: ReferendumDetailsViewProtocol?,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity]
    )

    func showVote(from view: ReferendumDetailsViewProtocol?, referendum: ReferendumLocal)

    func showVoters(
        from view: ReferendumDetailsViewProtocol?,
        referendum: ReferendumLocal,
        type: ReferendumVotersType
    )
}
