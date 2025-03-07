import Foundation

protocol ReferendumDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(votingDetails: ReferendumVotingStatusDetailsView.Model)
    func didReceive(dAppModels: [DAppView.Model]?)
    func didReceive(timelineModel: [ReferendumTimelineView.Model]?)
    func didReceive(titleModel: ReferendumDetailsTitleView.Model)
    func didReceive(yourVoteModel: [YourVoteRow.Model])
    func didReceive(requestedAmount: RequestedAmountRow.Model?)
    func didReceive(trackTagsModel: TrackTagsView.Model?)
    func didReceive(activeTimeViewModel: ReferendumInfoView.Time?)
    func didReceive(shouldHideFullDetails: Bool)
}

protocol ReferendumDetailsPresenterProtocol: AnyObject, WalletNoAccountHandling {
    func setup()
    func showProposerDetails()
    func readFullDescription()
    func showAyeVoters()
    func showNayVoters()
    func showAbstainVoters()
    func opeDApp(at index: Int)
    func openFullDetails()
    func vote()
    func openURL(_ url: URL)
    func share()
}

protocol ReferendumDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func refreshBlockTime()
    func refreshActionDetails()
    func refreshIdentities(for accountIds: Set<AccountId>)
    func remakeDAppsSubscription()
    func remakeSubscriptions()
}

protocol ReferendumDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendum(_ referendum: ReferendumLocal)
    func didReceiveVotingAmount(_ amount: ReferendumVotingAmount)
    func didReceiveActionDetails(_ actionDetails: ReferendumActionLocal)
    func didReceiveAccountVotes(
        _ votes: ReferendumAccountVoteLocal?,
        votingDistribution: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    )
    func didReceiveMetadata(_ referendumMetadata: ReferendumMetadataLocal?)
    func didReceiveIdentities(_ identities: [AccountAddress: AccountIdentity])
    func didReceiveRequestedAmountPrice(_ price: PriceData?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveDApps(_ dApps: [GovernanceDApps.DApp])
    func didReceiveError(_ error: ReferendumDetailsInteractorError)
}

protocol ReferendumDetailsWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    CommonRetryable,
    AddressOptionsPresentable,
    WebPresentable,
    NoAccountSupportPresentable,
    BrowserOpening,
    SharingPresentable {
    func showFullDetails(
        from view: ReferendumDetailsViewProtocol?,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        metadata: ReferendumMetadataLocal?,
        identities: [AccountAddress: AccountIdentity]
    )

    func showVote(
        from view: ReferendumDetailsViewProtocol?,
        referendum: ReferendumLocal,
        initData: ReferendumVotingInitData
    )

    func showVoters(
        from view: ReferendumDetailsViewProtocol?,
        referendum: ReferendumLocal,
        type: ReferendumVotersType
    )

    func showFullDescription(
        from view: ReferendumDetailsViewProtocol?,
        title: String,
        description: String
    )

    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel)
}
