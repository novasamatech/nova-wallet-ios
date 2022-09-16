import Foundation
import BigInt

extension ParaStkYieldBoostSetupInteractor: ParaStkYieldBoostScheduleInteractorOutputProtocol {
    func didReceiveScheduleAutocompound(feeInfo: RuntimeDispatchInfo) {
        presenter?.didReceiveScheduleAutocompound(feeInfo: feeInfo)
    }

    func didReceiveTaskExecution(fee: BigUInt) {
        presenter?.didReceiveTaskExecution(fee: fee)
    }

    func didReceiveTaskExecution(time: AutomationTime.UnixTime) {
        presenter?.didReceiveTaskExecution(time: time)
    }

    func didReceiveScheduleInteractor(error: ParaStkYieldBoostScheduleInteractorError) {
        presenter?.didReceiveScheduleInteractor(error: error)
    }
}

extension ParaStkYieldBoostSetupInteractor: ParaStkYieldBoostCancelInteractorOutputProtocol {
    func didReceiveCancelTask(feeInfo: RuntimeDispatchInfo) {
        presenter?.didReceiveCancelTask(feeInfo: feeInfo)
    }

    func didReceiveCancelInteractor(error: ParaStkYieldBoostCancelInteractorError) {
        presenter?.didReceiveCancelInteractor(error: error)
    }
}
