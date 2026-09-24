import Foundation
import SubstrateSdk

protocol AssetHubExchangeHostProtocol {
    var chain: ChainModel { get }
    var selectedAccount: ChainAccountResponse { get }
    var submissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol { get }
    var extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol { get }
    var signingWrapper: SigningWrapperProtocol { get }
    var extrinsicParamsFactory: AssetHubExchangeExtrinsicParamsFactoryProtocol { get }
    var runtimeService: RuntimeProviderProtocol { get }
    var connection: JSONRPCEngine { get }
    var operationQueue: OperationQueue { get }
    var executionTimeEstimator: AssetExchangeTimeEstimating { get }
    var flowState: AssetHubFlowStateProtocol { get }
    var logger: LoggerProtocol { get }
}

final class AssetHubExchangeHost: AssetHubExchangeHostProtocol {
    let chain: ChainModel
    let selectedAccount: ChainAccountResponse
    let flowState: AssetHubFlowStateProtocol
    let submissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol
    let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let extrinsicParamsFactory: AssetHubExchangeExtrinsicParamsFactoryProtocol
    let runtimeService: RuntimeProviderProtocol
    let connection: JSONRPCEngine
    let executionTimeEstimator: AssetExchangeTimeEstimating
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        selectedAccount: ChainAccountResponse,
        flowState: AssetHubFlowStateProtocol,
        submissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        extrinsicParamsFactory: AssetHubExchangeExtrinsicParamsFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        runtimeService: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        executionTimeEstimator: AssetExchangeTimeEstimating,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.flowState = flowState
        self.submissionMonitorFactory = submissionMonitorFactory
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.signingWrapper = signingWrapper
        self.extrinsicParamsFactory = extrinsicParamsFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.executionTimeEstimator = executionTimeEstimator
        self.operationQueue = operationQueue
        self.logger = logger
    }
}
