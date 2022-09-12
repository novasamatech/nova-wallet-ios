import Foundation

class ParaStkYieldBoostCancelInteractor {
    weak var presenter: ParaStkYieldBoostCancelInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol

    init(
        selectedAccount: ChainAccountResponse,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
    }
}

extension ParaStkYieldBoostCancelInteractor: ParaStkYieldBoostCancelInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
    }

    func estimateCancelAutocompoundFee(for taskId: AutomationTime.TaskId) {
        let identifier = "cancel-\(taskId.toHex())"

        let call = AutomationTime.CancelTaskCall(taskId: taskId)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            try builder.adding(call: call.runtimeCall)
        }
    }
}

extension ParaStkYieldBoostCancelInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        switch result {
        case let .success(feeInfo):
            presenter?.didReceiveCancelTask(feeInfo: feeInfo)
        case let .failure(error):
            presenter?.didReceiveCancelInteractor(error: .cancelFeeFetchFailed(error))
        }
    }
}
