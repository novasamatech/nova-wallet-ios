protocol ReferendumDetailsViewProtocol: AnyObject {}

protocol ReferendumDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol ReferendumDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ReferendumDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendum(_ referendum: ReferendumLocal)
    func didReceiveActionDetails(_ actionDetails: ReferendumActionLocal)
    func didReceiveMetadata(_ referendumMetadata: ReferendumMetadataLocal?)
    func didReceiveIdentities(_ identities: [AccountId: AccountIdentity])
    func didReceivePrice(_ price: PriceData?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveError(_ error: ReferendumDetailsInteractorError)
}

protocol ReferendumDetailsWireframeProtocol: AnyObject {}
