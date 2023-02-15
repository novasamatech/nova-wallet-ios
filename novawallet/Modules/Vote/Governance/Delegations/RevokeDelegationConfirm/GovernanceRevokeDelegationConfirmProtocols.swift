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

protocol GovernanceRevokeDelegationConfirmInteractorInputProtocol: GovernanceDelegateInteractorInputProtocol {
    func submitRevoke(for tracks: Set<TrackIdLocal>)
}

protocol GovernanceRevokeDelegationConfirmInteractorOutputProtocol: GovernanceDelegateInteractorOutputProtocol {
    func didReceiveSubmissionHash(_ hash: String)
    func didReceiveError(_ error: GovernanceRevokeDelegationInteractorError)
}

protocol GovernanceRevokeDelegationConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    FeeRetryable, MessageSheetPresentable,
    AddressOptionsPresentable, GovernanceErrorPresentable {
    func showTracks(from view: GovernanceRevokeDelegationConfirmViewProtocol?, tracks: [GovernanceTrackInfoLocal])

    func complete(
        on view: GovernanceRevokeDelegationConfirmViewProtocol?,
        allRemoved: Bool,
        locale: Locale
    )
}
