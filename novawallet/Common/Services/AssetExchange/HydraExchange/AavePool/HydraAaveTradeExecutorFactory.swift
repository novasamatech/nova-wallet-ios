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

    func createAaveTradePools(
        for pairs: [HydraAave.TradePair],
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<HydraAave.PoolsFetchResult>
}

extension HydraAaveTradeExecutorFactoryProtocol {
    func createAaveTradePairs() -> CompoundOperationWrapper<[HydraAave.TradePair]> {
        createAaveTradePairs(for: nil)
    }
}

final class HydraAaveTradeExecutorFactory {
    private static let individualPoolCallsConcurrency = 6

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

private extension HydraAaveTradeExecutorFactory {
    func createAaveTradePool(
        for pair: HydraAave.TradePair,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<HydraAave.PoolData> {
        stateCallFactory.createWrapper(
            path: HydraAave.traderPoolPath,
            paramsClosure: { runtimeApi, encoder, context in
                let inputs = runtimeApi.method.inputs
                guard inputs.count == 2 else {
                    throw SubstrateRuntimeApiOperationFactoryError.unexpectedParamsCount
                }

                try encoder.append(
                    StringCodable(wrappedValue: pair.asset1),
                    ofType: inputs[0].paramType.asTypeId(),
                    with: context.toRawContext()
                )

                try encoder.append(
                    StringCodable(wrappedValue: pair.asset2),
                    ofType: inputs[1].paramType.asTypeId(),
                    with: context.toRawContext()
                )
            },
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue,
            at: blockHash
        )
    }

    func createIndividualPoolsWrapper(
        for pairs: [HydraAave.TradePair],
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<HydraAave.PoolsFetchResult> {
        let poolsOperation = OperationCombiningService<HydraAave.PoolData>(
            operationManager: OperationManager(operationQueue: operationQueue),
            operationsPerBatch: Self.individualPoolCallsConcurrency
        ) {
            pairs.map { pair in
                self.createAaveTradePool(for: pair, blockHash: blockHash)
            }
        }.longrunOperation()

        let mappingOperation = ClosureOperation<HydraAave.PoolsFetchResult> {
            let pools = try poolsOperation.extractNoCancellableResultData()
            return HydraAave.PoolsFetchResult(pools: pools, source: .individual)
        }

        mappingOperation.addDependency(poolsOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [poolsOperation]
        )
    }

    func containsAll(
        pools: [HydraAave.PoolData],
        pairs: [HydraAave.TradePair]
    ) -> Bool {
        let poolPairs = Set(
            pools.map { HydraAave.TradePair(asset1: $0.reserve, asset2: $0.atoken) }
        )

        return poolPairs.isSuperset(of: pairs)
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

    func createAaveTradePools(
        for pairs: [HydraAave.TradePair],
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<HydraAave.PoolsFetchResult> {
        let aggregateWrapper = createAaveTradePools(for: blockHash)

        let resultWrapper: CompoundOperationWrapper<HydraAave.PoolsFetchResult>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            if
                let pools = try? aggregateWrapper.targetOperation.extractNoCancellableResultData(),
                self.containsAll(pools: pools, pairs: pairs) {
                return .createWithResult(
                    HydraAave.PoolsFetchResult(pools: pools, source: .aggregate)
                )
            }

            return self.createIndividualPoolsWrapper(for: pairs, blockHash: blockHash)
        }

        resultWrapper.addDependency(wrapper: aggregateWrapper)

        return resultWrapper.insertingHead(operations: aggregateWrapper.allOperations)
    }
}
