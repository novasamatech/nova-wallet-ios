import Foundation
import Foundation_iOS

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didRecieve(viewModel: LocalizableResource<PayoutConfirmViewModel>)
    func didRecieve(amountViewModel: LocalizableResource<BalanceViewModelProtocol>)
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingPayoutConfirmationPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func presentAccountOptions()
}

protocol StakingPayoutConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func submitPayout()
    func estimateFee()
}

protocol StakingPayoutConfirmationInteractorOutputProtocol: AnyObject {
    func didRecieve(account: MetaChainAccountResponse, rewardAmount: Decimal)

    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)

    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>)

    func didStartPayout()
    func didCompletePayout(by sender: ExtrinsicSenderResolution)
    func didFailPayout(error: Error)
}

protocol StakingPayoutConfirmationWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    StakingErrorPresentable,
    AddressOptionsPresentable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {}
