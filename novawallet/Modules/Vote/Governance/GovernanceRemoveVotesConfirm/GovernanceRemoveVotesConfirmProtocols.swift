import Foundation
import BigInt

protocol GovernanceRemoveVotesConfirmViewProtocol: ControllerBackedProtocol {}

protocol GovernanceRemoveVotesConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol GovernanceRemoveVotesConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for requests: [GovernanceRemoveVoteRequest])
    func submit(requests: [GovernanceRemoveVoteRequest])
    func remakeSubscriptions()
}

protocol GovernanceRemoveVotesConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveVotingResult(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveBalance(_ assetBalance: AssetBalance?)
    func didReceiveRemoveVotesHash(_ hash: String)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveError(_ error: GovernanceRemoveVotesInteractorError)
}

protocol GovernanceRemoveVotesConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
                                                            CommonRetryable, FeeRetryable {}
