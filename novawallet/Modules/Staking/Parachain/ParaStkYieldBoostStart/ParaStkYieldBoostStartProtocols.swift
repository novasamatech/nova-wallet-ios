import Foundation
import BigInt

protocol ParaStkYieldBoostStartViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveSender(viewModel: DisplayAddressViewModel)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveThreshold(viewModel: String)
    func didReceivePeriod(viewModel: UInt)
}

protocol ParaStkYieldBoostStartPresenterProtocol: AnyObject {
    func setup()
    func submit()
    func showSenderActions()
}

protocol ParaStkYieldBoostStartInteractorInputProtocol: ParaStkYieldBoostScheduleInteractorInputProtocol,
    ParaStkYieldBoostCommonInteractorInputProtocol {
    func schedule(
        for collatorId: AccountId,
        initTime: AutomationTime.UnixTime,
        frequency: AutomationTime.Seconds,
        accountMinimum: BigUInt,
        cancellingTaskIds: Set<AutomationTime.TaskId>
    )
}

protocol ParaStkYieldBoostStartInteractorOutputProtocol: ParaStkYieldBoostScheduleInteractorOutputProtocol,
    ParaStkYieldBoostCommonInteractorOutputProtocol {
    func didScheduleYieldBoost(for model: ExtrinsicSubmittedModel)
    func didReceiveConfirmation(error: ParaStkYieldBoostStartError)
}

protocol ParaStkYieldBoostStartWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable, MessageSheetPresentable, ParaStkYieldBoostErrorPresentable,
    AddressOptionsPresentable, ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {}
