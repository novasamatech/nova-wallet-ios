import Foundation

protocol GovernanceRevokeDelegationConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveDelegate(viewModel: GovernanceDelegateStackCell.Model)
    func didReceiveTracks(viewModel: GovernanceTracksViewModel)
    func didReceiveYourDelegation(viewModel: GovernanceYourDelegationViewModel)
    func didReceiveUndelegatingPeriod(viewModel: String)
    func didReceiveHints(viewModel: [String])
}

protocol GovernanceRevokeDelegationConfirmPresenterProtocol: AnyObject {
    func setup()
    func presentSenderAccount()
    func presentDelegateAccount()
    func presentTracks()
    func confirm()
}

protocol GovernanceRevokeDelegationConfirmInteractorInputProtocol: GovernanceDelegateInteractorInputProtocol,
    MultiExtrinsicSubmitRetryInputProtocol {
    func submitRevoke(for tracks: Set<TrackIdLocal>)
}

protocol GovernanceRevokeDelegationConfirmInteractorOutputProtocol: GovernanceDelegateInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: SubmitIndexedExtrinsicResult)
    func didReceiveError(_ error: GovernanceRevokeDelegationInteractorError)
}

protocol GovernanceRevokeDelegationConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    FeeRetryable, ExtrinsicSigningErrorHandling, MessageSheetPresentable, AddressOptionsPresentable,
    GovernanceErrorPresentable, MultiExtrinsicRetryable,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func showTracks(
        from view: GovernanceRevokeDelegationConfirmViewProtocol?,
        tracks: [GovernanceTrackInfoLocal],
        delegations: [TrackIdLocal: ReferendumDelegatingLocal]
    )

    func complete(
        on view: GovernanceRevokeDelegationConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution?,
        allRemoved: Bool,
        locale: Locale
    )

    func skip(on view: GovernanceRevokeDelegationConfirmViewProtocol?)
}
