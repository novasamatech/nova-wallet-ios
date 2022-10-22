import Foundation
import BigInt

protocol ReferendumVoteInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func estimateFee(for vote: ReferendumVoteAction)
}

protocol ReferendumVoteInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveVotingReferendum(_ referendum: ReferendumLocal)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveBaseError(_ error: ReferendumVoteInteractorError)
}
