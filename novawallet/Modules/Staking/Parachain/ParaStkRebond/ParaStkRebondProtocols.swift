import Foundation

protocol ParaStkRebondViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
    func didReceiveHints(viewModel: [String])
}

protocol ParaStkRebondPresenterProtocol: AnyObject {
    func setup()
    func selectAccount()
    func selectCollator()
    func confirm()
}

protocol ParaStkRebondInteractorInputProtocol: PendingExtrinsicInteracting {
    func setup()
    func estimateFee(for collator: AccountId)
    func submit(for collator: AccountId)
    func fetchIdentity(for collator: AccountId)
}

protocol ParaStkRebondInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didReceiveCollatorIdentity(_ identity: AccountIdentity?)
    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>)
    func didReceiveError(_ error: Error)
}

protocol ParaStkRebondWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(on view: ParaStkRebondViewProtocol?, locale: Locale)
}
