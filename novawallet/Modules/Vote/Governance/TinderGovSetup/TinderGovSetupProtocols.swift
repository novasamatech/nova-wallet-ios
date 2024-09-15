import Foundation

protocol TinderGovSetupViewProtocol: BaseReferendumVoteSetupViewProtocol {}

protocol TinderGovSetupPresenterProtocol: BaseReferendumVoteSetupPresenterProtocol {
    func proceed()
}

protocol TinderGovSetupInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func refreshLockDiff(
        for trackVoting: ReferendumTracksVotingDistribution,
        blockHash: Data?
    )
    func refreshBlockTime()
    func process(votingPower: VotingPowerLocal)
}

protocol TinderGovSetupInteractorOutputProtocol: AnyObject {
    func didProcessVotingPower()
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveLockStateDiff(_ stateDiff: GovernanceLockStateDiff)
    func didReceiveAccountVotes(
        _ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>
    )
    func didReceiveBlockNumber(_ number: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveBaseError(_ error: ReferendumVoteInteractorError)
}

protocol TinderGovSetupWireframeProtocol: BaseReferendumVoteSetupWireframeProtocol, ModalAlertPresenting {
    func showTinderGov(
        from view: ControllerBackedProtocol?,
        locale: Locale
    )
}
