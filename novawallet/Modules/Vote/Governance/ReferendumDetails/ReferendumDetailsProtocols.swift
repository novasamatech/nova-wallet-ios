protocol ReferendumDetailsViewProtocol: ControllerBackedProtocol {}

protocol ReferendumDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol ReferendumDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func refreshBlockTime()
    func refreshActionDetails()
    func refreshIdentities()
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
    func didReceiveError(_ error: ReferendumDetailsInteractorError)
}

protocol ReferendumDetailsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func showFullDetails(
        from view: ReferendumDetailsViewProtocol?,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity]
    )
}
