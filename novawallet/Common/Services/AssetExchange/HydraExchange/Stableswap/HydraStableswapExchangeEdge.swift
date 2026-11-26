import Foundation
import Operation_iOS

final class HydraStableswapExchangeEdge: AssetsHydraExchangeEdge {
    let quoteFactory: HydraStableswapQuoteFactory
    let poolAsset: HydraDx.AssetId

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        poolAsset: HydraDx.AssetId,
        host: HydraExchangeHostProtocol,
        quoteFactory: HydraStableswapQuoteFactory
    ) {
        self.quoteFactory = quoteFactory
        self.poolAsset = poolAsset

        super.init(
            origin: origin,
            destination: destination,
            remoteSwapPair: remoteSwapPair,
            host: host
        )
    }
}

extension HydraStableswapExchangeEdge: AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component {
        .init(
            assetIn: remoteSwapPair.assetIn,
            assetOut: remoteSwapPair.assetOut,
            type: .stableswap(poolAsset)
        )
    }
}

extension HydraStableswapExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { AssetsExchange.defaultEdgeWeight - 10 }

    func addingWeight(to currentWeight: Int, predecessor edge: AnyGraphEdgeProtocol?) -> Int {
        addingWeight(to: currentWeight, predecessor: edge, suggestedEdgeWeight: weight)
    }

    func quote(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        quoteFactory.quote(
            for: .init(
                assetIn: remoteSwapPair.assetIn,
                assetOut: remoteSwapPair.assetOut,
                poolAsset: poolAsset,
                amount: amount,
                direction: direction
            )
        )
    }

    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol {
        HydraExchangeAtomicOperation(
            host: host,
            operationArgs: args,
            edges: [self]
        )
    }

    func appendToOperation(
        _ operation: AssetExchangeAtomicOperationProtocol,
        args: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol? {
        appendToOperation(
            operation,
            edge: self,
            args: args
        )
    }

    func tradeLimitVerdict(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeTradeLimitVerdict> {
        let coderFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let minTradingLimitOperation: BaseOperation<Balance> = PrimitiveConstantOperation.operation(
            for: HydraStableswap.minTradingLimitPath,
            dependingOn: coderFactoryOperation
        )

        minTradingLimitOperation.addDependency(coderFactoryOperation)

        let poolPair = HydraStableswap.PoolPair(
            poolAsset: poolAsset,
            assetIn: remoteSwapPair.assetIn,
            assetOut: remoteSwapPair.assetOut
        )

        let verdictOperation = ClosureOperation<AssetExchangeTradeLimitVerdict> {
            let minTradingLimit = try HydraExchangeTradeLimits.optionalMinTradingLimit(from: minTradingLimitOperation)

            guard let minTradingLimit else {
                return .withinLimit
            }

            return HydraStableswapQuoteFactory.tradeLimitVerdict(
                for: amount,
                direction: direction,
                poolPair: poolPair,
                minTradingLimit: minTradingLimit
            )
        }

        verdictOperation.addDependency(minTradingLimitOperation)

        return CompoundOperationWrapper(
            targetOperation: verdictOperation,
            dependencies: [coderFactoryOperation, minTradingLimitOperation]
        )
    }
}
