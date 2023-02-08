import Foundation
import BigInt

protocol GovernanceDelegateInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func estimateFee(for actions: [GovernanceDelegatorAction])
    func refreshDelegateStateDiff(
        for trackVoting: ReferendumTracksVotingDistribution,
        newDelegation: GovernanceNewDelegation
    )
    func refreshBlockTime()
}

protocol GovernanceDelegateInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveDelegateStateDiff(_ stateDiff: GovernanceDelegateStateDiff)
    func didReceiveAccountVotes(
        _ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>
    )
    func didReceiveBlockNumber(_ number: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveBaseError(_ error: GovernanceDelegateInteractorError)
}
