import Foundation
import BigInt

extension ParaStkYieldBoostSetupPresenter {
    func didReceiveCancelTask(feeInfo: RuntimeDispatchInfo) {
        if !isYieldBoostSelected {
            updateExtrinsicFee(BigUInt(feeInfo.fee))
        }
    }

    func didReceiveCancelInteractor(error: ParaStkYieldBoostCancelInteractorError) {
        guard !isYieldBoostSelected else {
            return
        }

        switch error {
        case .cancelFeeFetchFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFeeIfNeeded()
            }
        }
    }
}
