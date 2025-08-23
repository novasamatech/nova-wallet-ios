import UIKit
import SubstrateSdk
import BigInt

final class ParaStkYieldBoostStartInteractor: ParaStkYieldBoostScheduleInteractor {
    var confirmPresenter: ParaStkYieldBoostStartInteractorOutputProtocol? {
        get {
            presenter as? ParaStkYieldBoostStartInteractorOutputProtocol
        }

        set {
            presenter = newValue
        }
    }

    let chain: ChainModel
    let signingWrapper: SigningWrapperProtocol
    let childCommonInteractor: ParaStkYieldBoostCommonInteractorInputProtocol

    private(set) var extrinsicSubscriptionId: UInt16?

    init(
        chain: ChainModel,
        selectedAccount: ChainAccountResponse,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        yieldBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        childCommonInteractor: ParaStkYieldBoostCommonInteractorInputProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.signingWrapper = signingWrapper
        self.childCommonInteractor = childCommonInteractor

        super.init(
            selectedAccount: selectedAccount,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            connection: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: requestFactory,
            yeildBoostOperationFactory: yieldBoostOperationFactory,
            operationQueue: operationQueue
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

extension ParaStkYieldBoostStartInteractor: ParaStkYieldBoostStartInteractorInputProtocol {
    func schedule(
        for collatorId: AccountId,
        initTime: AutomationTime.UnixTime,
        frequency: AutomationTime.Seconds,
        accountMinimum: BigUInt,
        cancellingTaskIds: Set<AutomationTime.TaskId>
    ) {
        let scheduleCall = AutomationTime.ScheduleAutocompoundCall(
            executionTime: initTime,
            frequency: frequency,
            collatorId: collatorId,
            accountMinimum: accountMinimum
        )

        let cancelCalls = cancellingTaskIds.map { AutomationTime.CancelTaskCall(taskId: $0) }

        let builderClosure: (ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol = { builder in
            let newBuilder = try cancelCalls.reduce(builder) { try $0.adding(call: $1.runtimeCall) }

            return try newBuilder.adding(call: scheduleCall.runtimeCall)
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
                    self?.confirmPresenter?.didScheduleYieldBoost(
                        for: updateModel.extrinsicSubmittedModel
                    )
                }
            case let .failure(error):
                self?.cancelExtrinsicSubscriptionIfNeeded()
                self?.confirmPresenter?.didReceiveConfirmation(error: .yieldBoostScheduleFailed(error))
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
}

extension ParaStkYieldBoostStartInteractor: ParaStkYieldBoostCommonInteractorInputProtocol {
    func retryCommonSubscriptions() {
        childCommonInteractor.retryCommonSubscriptions()
    }
}

extension ParaStkYieldBoostStartInteractor: ParaStkYieldBoostCommonInteractorOutputProtocol {
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
