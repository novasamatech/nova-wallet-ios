import Foundation
import BigInt

protocol StartStakingConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveStakingType(viewModel: String)
    func didReceiveStakingDetails(title: String, info: DisplayAddressViewModel)
}

protocol StartStakingConfirmPresenterProtocol: AnyObject {
    func setup()
    func selectSender()
    func selectStakingDetails()
    func confirm()
}

protocol StartStakingConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func retryRestrinctions()
    func estimateFee()
    func submit()
}

protocol StartStakingConfirmInteractorOutputProtocol: AnyObject {
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(price: PriceData?)
    func didReceive(fee: ExtrinsicFeeProtocol)
    func didReceive(restrictions: RelaychainStakingRestrictions)
    func didReceiveConfirmation(model: ExtrinsicSubmittedModel)
    func didReceive(error: StartStakingConfirmInteractorError)
}

protocol StartStakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, AddressOptionsPresentable, MessageSheetPresentable,
    ExtrinsicSubmissionPresenting, StakingErrorPresentable, ExtrinsicSigningErrorHandling {}

protocol StartStakingDirectConfirmWireframeProtocol: StartStakingConfirmWireframeProtocol {
    func showSelectedValidators(from view: StartStakingConfirmViewProtocol?, validators: PreparedValidators)
}
