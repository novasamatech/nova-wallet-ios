import Foundation
import Operation_iOS

final class HydraOmnipoolExchangeEdge: AssetsHydraExchangeEdge {
    let quoteFactory: HydraOmnipoolQuoteFactory

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        host: HydraExchangeHostProtocol,
        quoteFactory: HydraOmnipoolQuoteFactory
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

extension HydraOmnipoolExchangeEdge: AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component {
        .init(
            assetIn: remoteSwapPair.assetIn,
            assetOut: remoteSwapPair.assetOut,
            type: .omnipool
        )
    }
}

extension HydraOmnipoolExchangeEdge: AssetExchangableGraphEdge {
    var weight: Int { AssetsExchange.defaultEdgeWeight }

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

extension HydraOmnipoolExchangeEdge {
    func tradeLimitVerdict(
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeTradeLimitVerdict> {
        let coderFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let limitsWrapper = HydraExchangeTradeLimits.createPoolLimitsWrapper(
            for: .omnipool,
            dependingOn: coderFactoryOperation
        )

        limitsWrapper.addDependency(operations: [coderFactoryOperation])

        let stateWrapper = quoteFactory.quoteStateWrapper(for: remoteSwapPair)
        let feeWrapper = quoteFactory.defaultFeeWrapper()

        let verdictOperation = ClosureOperation<AssetExchangeTradeLimitVerdict> {
            let limits = try limitsWrapper.targetOperation.extractNoCancellableResultData()
            let remoteState = try stateWrapper.targetOperation.extractNoCancellableResultData()
            let defaultFee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            let params = try self.quoteFactory.deriveApiParams(
                from: remoteState,
                defaultFee: defaultFee
            )

            let verdict = try HydraOmnipoolQuoteFactory.tradeLimitVerdict(
                for: amount,
                direction: direction,
                params: params,
                limits: limits
            )

            guard let limitedAsset = self.limitedAsset(for: direction) else {
                return verdict
            }

            return verdict.naming(limitedAsset: limitedAsset)
        }

        verdictOperation.addDependency(limitsWrapper.targetOperation)
        verdictOperation.addDependency(stateWrapper.targetOperation)
        verdictOperation.addDependency(feeWrapper.targetOperation)

        let dependencies = [coderFactoryOperation]
            + limitsWrapper.allOperations
            + stateWrapper.allOperations
            + feeWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: verdictOperation, dependencies: dependencies)
    }
}
