import Foundation
import SubstrateSdk
import Operation_iOS

protocol ExtrinsicFeeEstimatorHostProtocol {
    var account: ChainAccountResponse { get }
    var chain: ChainModel { get }
    var connection: JSONRPCEngine { get }
    var runtimeProvider: RuntimeProviderProtocol { get }
    var userStorageFacade: StorageFacadeProtocol { get }
    var substrateStorageFacade: StorageFacadeProtocol { get }
    var operationQueue: OperationQueue { get }
    var logger: LoggerProtocol { get }
}

final class ExtrinsicFeeEstimatorHost: ExtrinsicFeeEstimatorHostProtocol {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue
        self.logger = logger
    }
}
