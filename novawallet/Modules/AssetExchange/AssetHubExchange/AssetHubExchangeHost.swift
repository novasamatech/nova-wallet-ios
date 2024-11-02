import Foundation
import SubstrateSdk

protocol AssetHubExchangeHostProtocol {
    var chain: ChainModel { get }
    var selectedAccount: ChainAccountResponse { get }
    var extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol { get }
    var signingWrapper: SigningWrapperProtocol { get }
    var runtimeService: RuntimeProviderProtocol { get }
    var connection: JSONRPCEngine { get }
    var operationQueue: OperationQueue { get }
}

final class AssetHubExchangeHost: AssetHubExchangeHostProtocol {
    let chain: ChainModel
    let selectedAccount: ChainAccountResponse
    let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let runtimeService: RuntimeProviderProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        selectedAccount: ChainAccountResponse,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        runtimeService: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.signingWrapper = signingWrapper
        self.runtimeService = runtimeService
        self.connection = connection
        self.operationQueue = operationQueue
    }
}
