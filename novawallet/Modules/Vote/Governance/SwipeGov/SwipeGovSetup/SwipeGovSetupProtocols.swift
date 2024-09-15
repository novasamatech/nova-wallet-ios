import Foundation

protocol SwipeGovSetupViewProtocol: BaseReferendumVoteSetupViewProtocol {}

protocol SwipeGovSetupPresenterProtocol: BaseReferendumVoteSetupPresenterProtocol {
    func proceed()
}

protocol SwipeGovSetupInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func refreshLockDiff(
        for trackVoting: ReferendumTracksVotingDistribution,
        blockHash: Data?
    )
    func refreshBlockTime()
    func process(votingPower: VotingPowerLocal)
}

protocol SwipeGovSetupInteractorOutputProtocol: AnyObject {
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

protocol SwipeGovSetupWireframeProtocol: BaseReferendumVoteSetupWireframeProtocol, ModalAlertPresenting {
    func showSwipeGov(
        from view: ControllerBackedProtocol?,
        locale: Locale
    )
}
