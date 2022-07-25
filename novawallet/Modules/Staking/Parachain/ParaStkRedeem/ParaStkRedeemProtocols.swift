import Foundation

protocol ParaStkRedeemViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
}

protocol ParaStkRedeemPresenterProtocol: AnyObject {
    func setup()
    func selectAccount()
    func confirm()
}

protocol ParaStkRedeemInteractorInputProtocol: PendingExtrinsicInteracting {
    func setup()
    func estimateFee(for collatorIds: Set<AccountId>)
    func submit(for collatorIds: Set<AccountId>)
}

protocol ParaStkRedeemInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didReceiveRoundInfo(_ roundInfo: ParachainStaking.RoundInfo?)
    func didCompleteExtrinsicSubmission(for result: Result<String, Error>)
    func didReceiveError(_ error: Error)
}

protocol ParaStkRedeemWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    NoSigningPresentable {
    func complete(on view: ParaStkRedeemViewProtocol?, locale: Locale)
}
