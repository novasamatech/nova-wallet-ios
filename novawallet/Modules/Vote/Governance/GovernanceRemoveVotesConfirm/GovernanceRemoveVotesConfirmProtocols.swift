import Foundation
import BigInt

protocol GovernanceRemoveVotesConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveTracks(viewModel: GovernanceTracksViewModel)
}

protocol GovernanceRemoveVotesConfirmPresenterProtocol: AnyObject {
    func setup()
    func showAccountOptions()
    func showTracks()
    func confirm()
}

protocol GovernanceRemoveVotesConfirmInteractorInputProtocol: MultiExtrinsicSubmitRetryInputProtocol {
    func setup()
    func estimateFee(for requests: [GovernanceRemoveVoteRequest])
    func submit(requests: [GovernanceRemoveVoteRequest])
    func remakeSubscriptions()
}

protocol GovernanceRemoveVotesConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveVotingResult(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveBalance(_ assetBalance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveSubmissionResult(_ result: SubmitIndexedExtrinsicResult)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveError(_ error: GovernanceRemoveVotesInteractorError)
}

protocol GovernanceRemoveVotesConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable, MessageSheetPresentable, AddressOptionsPresentable,
    ExtrinsicSubmissionPresenting, GovernanceErrorPresentable, ExtrinsicSigningErrorHandling, MultiExtrinsicRetryable {
    func showTracks(
        from view: GovernanceRemoveVotesConfirmViewProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    )

    func skip(on view: GovernanceRemoveVotesConfirmViewProtocol?)
}
