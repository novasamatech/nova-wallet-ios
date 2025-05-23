import Foundation
import SubstrateSdk

protocol HydraExchangeHostProtocol {
    var chain: ChainModel { get }
    var selectedAccount: ChainAccountResponse { get }
    var submissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol { get }
    var extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol { get }
    var extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol { get }
    var signingWrapper: SigningWrapperProtocol { get }
    var runtimeService: RuntimeProviderProtocol { get }
    var connection: JSONRPCEngine { get }
    var executionTimeEstimator: AssetExchangeTimeEstimating { get }
    var operationQueue: OperationQueue { get }
    var logger: LoggerProtocol { get }
}

final class HydraExchangeHost: HydraExchangeHostProtocol {
    let chain: ChainModel
    let selectedAccount: ChainAccountResponse

    let submissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol
    let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    let extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol
    let executionTimeEstimator: AssetExchangeTimeEstimating
    let runtimeService: RuntimeProviderProtocol
    let connection: JSONRPCEngine
    let signingWrapper: SigningWrapperProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        selectedAccount: ChainAccountResponse,
        submissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol,
        runtimeService: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        signingWrapper: SigningWrapperProtocol,
        executionTimeEstimator: AssetExchangeTimeEstimating,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.submissionMonitorFactory = submissionMonitorFactory
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.extrinsicParamsFactory = extrinsicParamsFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.signingWrapper = signingWrapper
        self.executionTimeEstimator = executionTimeEstimator
        self.operationQueue = operationQueue
        self.logger = logger
    }
}
