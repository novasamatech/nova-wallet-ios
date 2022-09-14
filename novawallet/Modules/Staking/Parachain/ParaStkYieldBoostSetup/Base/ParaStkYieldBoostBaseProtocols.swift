import Foundation
import BigInt

protocol ParaStkYieldBoostScheduleInteractorInputProtocol: AnyObject {
    func setup()

    func estimateScheduleAutocompoundFee(
        for collatorId: AccountId,
        initTime: AutomationTime.UnixTime,
        frequency: AutomationTime.Seconds,
        accountMinimum: BigUInt,
        cancellingTaskIds: Set<AutomationTime.TaskId>
    )

    func estimateTaskExecutionFee()

    func fetchTaskExecutionTime(for period: UInt)
}

protocol ParaStkYieldBoostCancelInteractorInputProtocol: AnyObject {
    func setup()
    func estimateCancelAutocompoundFee(for taskId: AutomationTime.TaskId)
}

protocol ParaStkYieldBoostCommonInteractorInputProtocol: AnyObject {
    func setup()
    func retryCommonSubscriptions()
}

enum ParaStkYieldBoostScheduleInteractorError: Error {
    case scheduleFeeFetchFailed(_ internalError: Error)
    case taskExecutionFeeFetchFailed(_ internalError: Error)
    case taskExecutionTimeFetchFailed(_ internalError: Error)
}

enum ParaStkYieldBoostCancelInteractorError: Error {
    case cancelFeeFetchFailed(_ internalError: Error)
}

enum ParaStkYieldBoostCommonInteractorError: Error {
    case balanceSubscriptionFailed(_ internalError: Error)
    case priceSubscriptionFailed(_ internalError: Error)
    case yieldBoostTasksSubscriptionFailed(_ internalError: Error)
}

protocol ParaStkYieldBoostScheduleInteractorOutputProtocol: AnyObject {
    func didReceiveScheduleAutocompound(feeInfo: RuntimeDispatchInfo)
    func didReceiveTaskExecution(fee: BigUInt)
    func didReceiveTaskExecution(time: AutomationTime.UnixTime)
    func didReceiveScheduleInteractor(error: ParaStkYieldBoostScheduleInteractorError)
}

protocol ParaStkYieldBoostCancelInteractorOutputProtocol: AnyObject {
    func didReceiveCancelTask(feeInfo: RuntimeDispatchInfo)
    func didReceiveCancelInteractor(error: ParaStkYieldBoostCancelInteractorError)
}

protocol ParaStkYieldBoostCommonInteractorOutputProtocol: AnyObject {
    func didReceiveAsset(balance: AssetBalance?)
    func didReceiveAsset(price: PriceData?)
    func didReceiveYieldBoost(tasks: [ParaStkYieldBoostState.Task]?)
    func didReceiveCommonInteractor(error: ParaStkYieldBoostCommonInteractorError)
}
