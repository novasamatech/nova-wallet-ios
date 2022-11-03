import Foundation

protocol GovernanceUnlockInteractorInputProtocol: AnyObject {
    func setup()
    func refreshBlockTime()
    func refreshUnlockSchedule(for tracksVoting: ReferendumTracksVotingDistribution, blockHash: Data?)
    func remakeSubscriptions()
}

protocol GovernanceUnlockInteractorOutputProtocol: AnyObject {
    func didReceiveVoting(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveUnlockSchedule(_ schedule: GovernanceUnlockSchedule)
    func didReceiveBlockNumber(_ block: BlockNumber)
    func didReceiveBlockTime(_ time: BlockTime)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveBaseError(_ error: GovernanceUnlockInteractorError)
}
