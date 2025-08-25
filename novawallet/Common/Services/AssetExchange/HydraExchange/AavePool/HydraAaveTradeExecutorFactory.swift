import Foundation
import Operation_iOS
import SubstrateSdk

protocol HydraAaveTradeExecutorFactoryProtocol {
    func createAaveTradePairs(
        for blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[HydraAave.TradePair]>

    func createAaveTradePools(
        for blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[HydraAave.PoolData]>
}

extension HydraAaveTradeExecutorFactoryProtocol {
    func createAaveTradePairs() -> CompoundOperationWrapper<[HydraAave.TradePair]> {
        createAaveTradePairs(for: nil)
    }
}

final class HydraAaveTradeExecutorFactory {
    let stateCallFactory = StateCallRequestFactory()
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }
}

extension HydraAaveTradeExecutorFactory: HydraAaveTradeExecutorFactoryProtocol {
    func createAaveTradePairs(
        for blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[HydraAave.TradePair]> {
        stateCallFactory.createWrapper(
            path: HydraAave.traderPairsPath,
            paramsClosure: nil,
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue,
            at: blockHash
        )
    }

    func createAaveTradePools(
        for blockHash: BlockHash?
    ) -> CompoundOperationWrapper<[HydraAave.PoolData]> {
        stateCallFactory.createWrapper(
            path: HydraAave.traderPoolsPath,
            paramsClosure: nil,
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue,
            at: blockHash
        )
    }
}
