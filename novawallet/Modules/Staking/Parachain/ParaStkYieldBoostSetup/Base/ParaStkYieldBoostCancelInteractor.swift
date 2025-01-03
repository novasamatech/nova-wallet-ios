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

    func performSetup() {
        feeProxy.delegate = self
    }
}

extension ParaStkYieldBoostCancelInteractor: ParaStkYieldBoostCancelInteractorInputProtocol {
    func setup() {
        performSetup()
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
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(feeInfo):
            presenter?.didReceiveCancelTask(feeInfo: feeInfo)
        case let .failure(error):
            presenter?.didReceiveCancelInteractor(error: .cancelFeeFetchFailed(error))
        }
    }
}
