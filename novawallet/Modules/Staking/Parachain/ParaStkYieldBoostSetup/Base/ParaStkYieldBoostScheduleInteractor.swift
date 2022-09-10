import Foundation
import BigInt
import SubstrateSdk

class ParaStkYieldBoostScheduleInteractor {
    weak var presenter: ParaStkYieldBoostScheduleInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let yeildBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        selectedAccount: ChainAccountResponse,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        yeildBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.requestFactory = requestFactory
        self.yeildBoostOperationFactory = yeildBoostOperationFactory
        self.operationQueue = operationQueue
    }
}

extension ParaStkYieldBoostScheduleInteractor: ParaStkYieldBoostScheduleInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
    }

    func estimateScheduleAutocompoundFee(
        for collatorId: AccountId,
        initTime: AutomationTime.UnixTime,
        frequency: AutomationTime.Seconds,
        accountMinimum: BigUInt
    ) {
        let identifier = "schedule-\(collatorId.toHex())-\(initTime)-\(frequency)-\(accountMinimum)"

        let call = AutomationTime.ScheduleAutocompoundCall(
            executionTime: initTime,
            frequency: frequency,
            collatorId: collatorId,
            accountMinimum: accountMinimum
        )

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier
        ) { builder in
            try builder.adding(call: call.runtimeCall)
        }
    }

    func estimateTaskExecutionFee() {
        let wrapper = yeildBoostOperationFactory.createAutocompoundFeeOperation(for: connection)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let fee = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveTaskExecution(fee: fee)
                } catch {
                    self?.presenter?.didReceiveScheduleInteractor(error: .taskExecutionFeeFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func fetchTaskExecutionTime(for period: UInt) {
        let wrapper = yeildBoostOperationFactory.createExecutionTimeOperation(
            for: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: requestFactory,
            periodInDays: period
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let executionTime = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveTaskExecution(time: executionTime)
                } catch {
                    self?.presenter?.didReceiveScheduleInteractor(error: .taskExecutionFeeFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension ParaStkYieldBoostScheduleInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        switch result {
        case let .success(feeInfo):
            presenter?.didReceiveScheduleAutocompound(feeInfo: feeInfo)
        case let .failure(error):
            presenter?.didReceiveScheduleInteractor(error: .scheduleFeeFetchFailed(error))
        }
    }
}
