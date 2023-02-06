import Foundation
import BigInt

protocol GovernanceRemoveVotesConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveTracks(viewModel: String)
}

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
    func didReceivePrice(_ price: PriceData?)
    func didReceiveRemoveVotesHash(_ hash: String)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveError(_ error: GovernanceRemoveVotesInteractorError)
}

protocol GovernanceRemoveVotesConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable, MessageSheetPresentable, AddressOptionsPresentable,
    ExtrinsicSubmissionPresenting, GovernanceErrorPresentable {}
