import Foundation
import BigInt

protocol ParaStkYieldBoostScheduleConfirmViewProtocol: ControllerBackedProtocol {}

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
    CommonRetryable, FeeRetryable, MessageSheetPresentable, ParaStkYieldBoostErrorPresentable, AddressOptionsPresentable {}
