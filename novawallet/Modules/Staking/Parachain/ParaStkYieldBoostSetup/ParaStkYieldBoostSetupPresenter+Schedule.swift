import Foundation
import BigInt

extension ParaStkYieldBoostSetupPresenter {
    func didReceiveScheduleAutocompound(feeInfo: RuntimeDispatchInfo) {
        // allow fee update is yield boost selected or not enabled previously
        if isYieldBoostSelected ||
            yieldBoostTasks?.first(where: { $0.collatorId == selectedCollator }) == nil {
            updateExtrinsicFee(BigUInt(feeInfo.fee))

            provideNetworkFee()
        }
    }

    func didReceiveTaskExecution(fee: BigUInt) {
        if isYieldBoostSelected {
            updateTaskExecutionFee(fee)
        }
    }

    func didReceiveTaskExecution(time: AutomationTime.UnixTime) {
        if isYieldBoostSelected {
            updateTaskExecutionTime(time)

            refreshExtrinsicFee()
        }
    }

    func didReceiveScheduleInteractor(error: ParaStkYieldBoostScheduleInteractorError) {
        guard isYieldBoostSelected else {
            return
        }

        logger.error("Schedule interactor error: \(error)")

        switch error {
        case .scheduleFeeFetchFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFeeIfNeeded()
            }
        case .taskExecutionFeeFetchFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.estimateTaskExecutionFee()
            }
        case .taskExecutionTimeFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshTaskExecutionTime()
            }
        }
    }
}
