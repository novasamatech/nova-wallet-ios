import UIKit

final class ParaStkYieldBoostStopInteractor: ParaStkYieldBoostCancelInteractor {
    var confirmPresenter: ParaStkYieldBoostStopInteractorOutputProtocol? {
        get {
            presenter as? ParaStkYieldBoostStopInteractorOutputProtocol
        }

        set {
            presenter = newValue
        }
    }

    let childCommonInteractor: ParaStkYieldBoostCommonInteractorInputProtocol
    let signingWrapper: SigningWrapperProtocol

    init(
        selectedAccount: ChainAccountResponse,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        signingWrapper: SigningWrapperProtocol,
        childCommonInteractor: ParaStkYieldBoostCommonInteractorInputProtocol
    ) {
        self.signingWrapper = signingWrapper
        self.childCommonInteractor = childCommonInteractor

        super.init(
            selectedAccount: selectedAccount,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy
        )
    }

    override func performSetup() {
        super.performSetup()

        childCommonInteractor.setup()
    }
}

extension ParaStkYieldBoostStopInteractor: ParaStkYieldBoostStopInteractorInputProtocol {
    func stopAutocompound(by taskId: AutomationTime.TaskId) {
        let call = AutomationTime.CancelTaskCall(taskId: taskId)

        let closure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: call.runtimeCall)
        }

        extrinsicService.submit(closure, signer: signingWrapper, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(hash):
                self?.confirmPresenter?.didStopAutocompound(with: hash)
            case let .failure(error):
                self?.confirmPresenter?.didReceiveStopAutocompound(error: .yieldBoostStopFailed(error))
            }
        }
    }

    func retryCommonSubscriptions() {
        childCommonInteractor.retryCommonSubscriptions()
    }
}

extension ParaStkYieldBoostStopInteractor: ParaStkYieldBoostCommonInteractorOutputProtocol {
    func didReceiveAsset(balance: AssetBalance?) {
        confirmPresenter?.didReceiveAsset(balance: balance)
    }

    func didReceiveAsset(price: PriceData?) {
        confirmPresenter?.didReceiveAsset(price: price)
    }

    func didReceiveYieldBoost(tasks: [ParaStkYieldBoostState.Task]?) {
        confirmPresenter?.didReceiveYieldBoost(tasks: tasks)
    }

    func didReceiveCommonInteractor(error: ParaStkYieldBoostCommonInteractorError) {
        confirmPresenter?.didReceiveCommonInteractor(error: error)
    }
}
