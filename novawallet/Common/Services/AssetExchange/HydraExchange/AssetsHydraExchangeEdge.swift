import Foundation
import Operation_iOS

protocol AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component { get }
}

class AssetsHydraExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId
    let remoteSwapPair: HydraDx.RemoteSwapPair
    let host: HydraExchangeHostProtocol

    var type: AssetExchangeEdgeType { .hydraSwap }

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        host: HydraExchangeHostProtocol
    ) {
        self.origin = origin
        self.destination = destination
        self.remoteSwapPair = remoteSwapPair
        self.host = host
    }

    func appendToOperation(
        _ operation: AssetExchangeAtomicOperationProtocol,
        edge: any HydraExchangeAtomicOperation.Edge,
        args: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol? {
        guard
            let hydraOperation = operation as? HydraExchangeAtomicOperation,
            let lastEdge = hydraOperation.edges.last,
            edge.origin == lastEdge.destination else {
            return nil
        }

        return HydraExchangeAtomicOperation(
            host: hydraOperation.host,
            operationArgs: hydraOperation.operationArgs.extending(with: args),
            edges: hydraOperation.edges + [edge]
        )
    }

    /// Names the pool asset a trade-limit rejection is denominated in. The quote factories work in
    /// `HydraDx.AssetId` space and cannot resolve a local `ChainAsset`; the route manager holds only a
    /// type-erased edge and so cannot resolve an intermediate hop's asset either. This edge is the one
    /// place that has both the remote pair and the chain, so it is where the cap acquires an asset.
    ///
    /// The asset is the one the *given* amount is denominated in — `origin` for a sell, `destination`
    /// for a buy, matching the cap's own direction. A rejection carrying no cap, or naming an asset
    /// this chain does not know, is rethrown untouched: the candidate path is still pruned, it just
    /// cannot be reported.
    func namingLimitedAsset(
        _ wrapper: CompoundOperationWrapper<Balance>,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        let chain = host.chain
        let localAssetId = switch direction {
        case .sell: origin.assetId
        case .buy: destination.assetId
        }

        let mappingOperation = ClosureOperation<Balance> {
            do {
                return try wrapper.targetOperation.extractNoCancellableResultData()
            } catch let HydraExchangeTradeLimitError.exceedsPoolTradeLimit(cap) {
                guard let cap, let limitedAsset = chain.chainAsset(for: localAssetId) else {
                    throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit(cap)
                }

                throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit(
                    cap.naming(limitedAsset: limitedAsset)
                )
            }
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mappingOperation)
    }

    func shouldIgnoreFeeRequirement(after edge: any AssetExchangableGraphEdge) -> Bool {
        type == edge.type
    }

    func shouldIgnoreDelayedCallRequirement(after edge: any AssetExchangableGraphEdge) -> Bool {
        type == edge.type
    }

    func canPayNonNativeFeesInIntermediatePosition() -> Bool {
        true
    }

    func requiresOriginKeepAliveOnIntermediatePosition() -> Bool {
        false
    }

    func beginMetaOperation(
        for amountIn: Balance,
        amountOut: Balance
    ) throws -> AssetExchangeMetaOperationProtocol {
        guard let assetIn = host.chain.chainAsset(for: origin.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: origin.assetId)
        }

        guard let assetOut = host.chain.chainAsset(for: destination.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: destination.assetId)
        }

        return HydraExchangeMetaOperation(
            assetIn: assetIn,
            assetOut: assetOut,
            amountIn: amountIn,
            amountOut: amountOut
        )
    }

    func appendToMetaOperation(
        _ currentOperation: AssetExchangeMetaOperationProtocol,
        amountIn _: Balance,
        amountOut: Balance
    ) throws -> AssetExchangeMetaOperationProtocol? {
        guard
            let hydraOperation = currentOperation as? HydraExchangeMetaOperation,
            hydraOperation.assetOut.chainAssetId == origin else {
            return nil
        }

        guard let newAssetOut = host.chain.chainAsset(for: destination.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: destination.assetId)
        }

        return HydraExchangeMetaOperation(
            assetIn: currentOperation.assetIn,
            assetOut: newAssetOut,
            amountIn: hydraOperation.amountIn,
            amountOut: amountOut
        )
    }

    func beginOperationPrototype() throws -> AssetExchangeOperationPrototypeProtocol {
        guard let assetIn = host.chain.chainAsset(for: origin.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: origin.assetId)
        }

        guard let assetOut = host.chain.chainAsset(for: destination.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: destination.assetId)
        }

        return HydraExchangeOperationPrototype(assetIn: assetIn, assetOut: assetOut, host: host)
    }

    func appendToOperationPrototype(
        _ currentPrototype: AssetExchangeOperationPrototypeProtocol
    ) throws -> AssetExchangeOperationPrototypeProtocol? {
        guard
            let hydraOperation = currentPrototype as? HydraExchangeOperationPrototype,
            hydraOperation.assetOut.chainAssetId == origin else {
            return nil
        }

        guard let newAssetOut = host.chain.chainAsset(for: destination.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: destination.assetId)
        }

        return HydraExchangeOperationPrototype(
            assetIn: currentPrototype.assetIn,
            assetOut: newAssetOut,
            host: host
        )
    }

    func addingWeight(
        to currentWeight: Int,
        predecessor edge: AnyGraphEdgeProtocol?,
        suggestedEdgeWeight: Int
    ) -> Int {
        guard
            let predecessorEdge = edge as? (any AssetExchangableGraphEdge),
            predecessorEdge.type == type
        else {
            return currentWeight + suggestedEdgeWeight
        }

        return currentWeight + (suggestedEdgeWeight / AssetsExchange.mergingEdgesWeightDivider)
    }
}

private extension AssetExchangeAtomicOperationArgs {
    func extending(
        with newOperationArgs: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationArgs {
        .init(
            swapLimit: .init(
                direction: swapLimit.direction,
                amountIn: swapLimit.amountIn,
                amountOut: newOperationArgs.swapLimit.amountOut,
                slippage: newOperationArgs.swapLimit.slippage
            ),
            feeAsset: feeAsset,
            commission: newOperationArgs.commission ?? commission
        )
    }
}
