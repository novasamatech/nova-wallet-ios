import Foundation
import Operation_iOS

final class AssetsHydraXYKExchangeEdge: AssetsHydraExchangeEdge {
    let quoteFactory: HydraXYKSwapQuoteFactory

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        host: HydraExchangeHostProtocol,
        quoteFactory: HydraXYKSwapQuoteFactory
    ) {
        self.quoteFactory = quoteFactory

        super.init(
            origin: origin,
            destination: destination,
            remoteSwapPair: remoteSwapPair,
            host: host
        )
    }
}

extension AssetsHydraXYKExchangeEdge: AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component {
        .init(
            assetIn: remoteSwapPair.assetIn,
            assetOut: remoteSwapPair.assetOut,
            type: .xyk
        )
    }
}

extension AssetsHydraXYKExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { AssetsExchange.defaultEdgeWeight + 10 }

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
}

extension AssetsHydraXYKExchangeEdge: AssetExchangeTradeLimitedEdge {
    func tradeLimitVerdict(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeTradeLimitVerdict> {
        let coderFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let limitsWrapper = HydraExchangeTradeLimits.createPoolLimitsWrapper(
            for: .xyk,
            dependingOn: coderFactoryOperation
        )

        limitsWrapper.addDependency(operations: [coderFactoryOperation])

        let stateWrapper = quoteFactory.quoteStateWrapper(for: remoteSwapPair)

        let verdictOperation = ClosureOperation<AssetExchangeTradeLimitVerdict> {
            let limits = try limitsWrapper.targetOperation.extractNoCancellableResultData()
            let remoteState = try stateWrapper.targetOperation.extractNoCancellableResultData()

            let verdict = try HydraXYKSwapQuoteFactory.tradeLimitVerdict(
                for: amount,
                direction: direction,
                remoteState: remoteState,
                limits: limits
            )

            guard let limitedAsset = self.limitedAsset(for: direction) else {
                return verdict
            }

            return verdict.naming(limitedAsset: limitedAsset)
        }

        verdictOperation.addDependency(limitsWrapper.targetOperation)
        verdictOperation.addDependency(stateWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: verdictOperation,
            dependencies: [coderFactoryOperation] + limitsWrapper.allOperations + stateWrapper.allOperations
        )
    }
}
