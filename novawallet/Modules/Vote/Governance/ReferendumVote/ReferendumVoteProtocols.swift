import Foundation
import BigInt

protocol ReferendumVoteInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func estimateFee(for vote: ReferendumVoteAction)
    func refreshLockDiff(
        for votes: [ReferendumIdLocal: ReferendumAccountVoteLocal],
        newVote: ReferendumNewVote?,
        blockHash: Data?
    )
    func refreshBlockTime()
}

protocol ReferendumVoteInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveVotingReferendum(_ referendum: ReferendumLocal)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveLockStateDiff(_ stateDiff: GovernanceLockStateDiff)
    func didReceiveAccountVotes(
        _ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>
    )
    func didReceiveBlockNumber(_ number: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveBaseError(_ error: ReferendumVoteInteractorError)
}
