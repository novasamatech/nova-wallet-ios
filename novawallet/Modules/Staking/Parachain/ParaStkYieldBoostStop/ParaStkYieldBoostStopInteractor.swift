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

    private(set) var extrinsicSubscriptionId: UInt16?

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

    deinit {
        cancelExtrinsicSubscriptionIfNeeded()
    }

    private func cancelExtrinsicSubscriptionIfNeeded() {
        if let extrinsicSubscriptionId = extrinsicSubscriptionId {
            extrinsicService.cancelExtrinsicWatch(for: extrinsicSubscriptionId)
            self.extrinsicSubscriptionId = nil
        }
    }

    override func performSetup() {
        super.performSetup()

        childCommonInteractor.setup()
    }
}

extension ParaStkYieldBoostStopInteractor: ParaStkYieldBoostStopInteractorInputProtocol {
    func stopAutocompound(by taskId: AutomationTime.TaskId) {
        let call = AutomationTime.CancelTaskCall(taskId: taskId)

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: call.runtimeCall)
        }

        let subscriptionIdClosure: ExtrinsicSubscriptionIdClosure = { [weak self] subscriptionId in
            self?.extrinsicSubscriptionId = subscriptionId

            return self != nil
        }

        let notificationClosure: ExtrinsicSubscriptionStatusClosure = { [weak self] result in
            switch result {
            case let .success(updateModel):
                if case .inBlock = updateModel.statusUpdate.extrinsicStatus {
                    self?.cancelExtrinsicSubscriptionIfNeeded()
                    self?.confirmPresenter?.didStopAutocompound(
                        with: updateModel.extrinsicSubmittedModel
                    )
                }
            case let .failure(error):
                self?.cancelExtrinsicSubscriptionIfNeeded()
                self?.confirmPresenter?.didReceiveStopAutocompound(error: .yieldBoostStopFailed(error))
            }
        }

        extrinsicService.submitAndWatch(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            subscriptionIdClosure: subscriptionIdClosure,
            notificationClosure: notificationClosure
        )
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
