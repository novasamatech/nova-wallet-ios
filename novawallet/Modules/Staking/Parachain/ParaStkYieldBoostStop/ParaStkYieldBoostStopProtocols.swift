import Foundation

protocol ParaStkYieldBoostStopViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveSender(viewModel: DisplayAddressViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
}

protocol ParaStkYieldBoostStopPresenterProtocol: AnyObject {
    func setup()
    func submit()
    func showSenderActions()
}

protocol ParaStkYieldBoostStopInteractorInputProtocol: ParaStkYieldBoostCancelInteractorInputProtocol,
    ParaStkYieldBoostCommonInteractorInputProtocol {
    func stopAutocompound(by taskId: AutomationTime.TaskId)
}

protocol ParaStkYieldBoostStopInteractorOutputProtocol: ParaStkYieldBoostCancelInteractorOutputProtocol,
    ParaStkYieldBoostCommonInteractorOutputProtocol {
    func didStopAutocompound(with model: ExtrinsicSubmittedModel)
    func didReceiveStopAutocompound(error: ParaStkYieldBoostStopError)
}

protocol ParaStkYieldBoostStopWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable, MessageSheetPresentable,
    ParaStkYieldBoostErrorPresentable, AddressOptionsPresentable,
    ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {}
