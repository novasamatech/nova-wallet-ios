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

        let extrinsicClosure: ExtrinsicBuilderClosure = { builder in
            let newBuilder = try builder.adding(call: scheduleCall.runtimeCall)

            return try cancelCalls.reduce(newBuilder) { try $0.adding(call: $1.runtimeCall) }
        }

        extrinsicService.submit(extrinsicClosure, signer: signingWrapper, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(hash):
                self?.confirmPresenter?.didScheduleYieldBoost(for: hash)
            case let .failure(error):
                self?.confirmPresenter?.didReceiveConfirmation(error: .yieldBoostScheduleFailed(error))
            }
        }
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
