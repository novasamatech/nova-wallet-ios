import Foundation
import BigInt

extension ParaStkYieldBoostSetupPresenter {
    func didReceiveCancelTask(feeInfo: ExtrinsicFeeProtocol) {
        if !isYieldBoostSelected {
            updateExtrinsicFee(feeInfo.amount)

            provideNetworkFee()
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
