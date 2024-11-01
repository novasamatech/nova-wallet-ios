import Foundation
import SubstrateSdk

protocol HydraSwapHostProtocol {
    var chain: ChainModel { get }
    var selectedAccount: ChainAccountResponse { get }
    var extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol { get }
    var extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol { get }
    var signingWrapper: SigningWrapperProtocol { get }
    var runtimeService: RuntimeProviderProtocol { get }
    var connection: JSONRPCEngine { get }
    var operationQueue: OperationQueue { get }
}

final class HydraSwapHost: HydraSwapHostProtocol {
    let chain: ChainModel
    let selectedAccount: ChainAccountResponse
    let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    let extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol
    let runtimeService: RuntimeProviderProtocol
    let connection: JSONRPCEngine
    let signingWrapper: SigningWrapperProtocol
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        selectedAccount: ChainAccountResponse,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol,
        runtimeService: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        signingWrapper: SigningWrapperProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.extrinsicParamsFactory = extrinsicParamsFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.signingWrapper = signingWrapper
        self.operationQueue = operationQueue
    }
}
