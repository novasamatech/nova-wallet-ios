import Foundation
import BigInt

protocol ReferendumVoteInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func estimateFee(for votes: [ReferendumNewVote])
    func refreshLockDiff(
        for trackVoting: ReferendumTracksVotingDistribution,
        newVotes: [ReferendumNewVote]
    )
    func refreshBlockTime()
}

protocol ReferendumVoteInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveLockStateDiff(_ stateDiff: GovernanceLockStateDiff)
    func didReceiveBlockNumber(_ number: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveBaseError(_ error: ReferendumVoteInteractorError)
}

protocol ReferendumObservingVoteInteractorOutputProtocol: ReferendumVoteInteractorOutputProtocol {
    func didReceiveVotingReferendumsState(_ state: ReferendumsState)
}
