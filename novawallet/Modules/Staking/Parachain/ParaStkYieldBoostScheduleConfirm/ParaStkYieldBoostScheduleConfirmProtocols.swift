import Foundation
import BigInt

protocol ParaStkYieldBoostScheduleConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveSender(viewModel: DisplayAddressViewModel)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveThreshold(viewModel: String)
    func didReceivePeriod(viewModel: UInt)
}

protocol ParaStkYieldBoostScheduleConfirmPresenterProtocol: AnyObject {
    func setup()
    func submit()
    func showSenderActions()
}

protocol ParaStkYieldBoostScheduleConfirmInteractorInputProtocol: ParaStkYieldBoostScheduleInteractorInputProtocol,
    ParaStkYieldBoostCommonInteractorInputProtocol {
    func schedule(
        for collatorId: AccountId,
        initTime: AutomationTime.UnixTime,
        frequency: AutomationTime.Seconds,
        accountMinimum: BigUInt,
        cancellingTaskIds: Set<AutomationTime.TaskId>
    )
}

protocol ParaStkYieldBoostScheduleConfirmInteractorOutputProtocol: ParaStkYieldBoostScheduleInteractorOutputProtocol,
    ParaStkYieldBoostCommonInteractorOutputProtocol {
    func didScheduleYieldBoost(for extrinsicHash: String)
    func didReceiveConfirmation(error: ParaStkYieldBoostScheduleConfirmError)
}

protocol ParaStkYieldBoostScheduleConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable, MessageSheetPresentable, ParaStkYieldBoostErrorPresentable, AddressOptionsPresentable {
    func complete(on view: ParaStkYieldBoostScheduleConfirmViewProtocol?, locale: Locale)
}
