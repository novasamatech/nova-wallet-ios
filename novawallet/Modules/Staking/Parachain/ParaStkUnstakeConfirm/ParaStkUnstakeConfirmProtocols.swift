import Foundation

protocol ParaStkUnstakeConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
    func didReceiveHints(viewModel: [String])
}

protocol ParaStkUnstakeConfirmPresenterProtocol: AnyObject {
    func setup()
    func selectAccount()
    func selectCollator()
    func confirm()
}

protocol ParaStkUnstakeConfirmInteractorInputProtocol: ParaStkBaseUnstakeInteractorInputProtocol,
    PendingExtrinsicInteracting {
    func confirm(for callWrapper: UnstakeCallWrapper)
}

protocol ParaStkUnstakeConfirmInteractorOutputProtocol: ParaStkBaseUnstakeInteractorOutputProtocol {
    func didCompleteExtrinsicSubmission(for result: Result<String, Error>)
}

protocol ParaStkUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    NoSigningPresentable {
    func complete(on view: ParaStkUnstakeConfirmViewProtocol?, locale: Locale)
}
