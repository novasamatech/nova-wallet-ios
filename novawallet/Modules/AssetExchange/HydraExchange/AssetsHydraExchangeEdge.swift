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

    func shouldIgnoreFeeRequirement(after edge: any AssetExchangableGraphEdge) -> Bool {
        type == edge.type
    }

    func canPayNonNativeFeesInIntermediatePosition() -> Bool {
        true
    }
    
    func beginMetaOperation(
        edge: any HydraExchangeAtomicOperation.Edge,
        amountIn: Balance,
        amountOut: Balance
    ) throws -> AssetExchangeMetaOperationProtocol {
        guard let assetIn = host.chain.chainAsset(for: edge.origin.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: edge.origin.assetId)
        }
        
        guard let assetOut = host.chain.chainAsset(for: edge.destination.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: edge.destination.assetId)
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
        edge: any HydraExchangeAtomicOperation.Edge,
        amountIn: Balance,
        amountOut: Balance
    ) throws -> AssetExchangeMetaOperationProtocol? {
        guard
            let hydraOperation = currentOperation as? HydraExchangeMetaOperation,
            hydraOperation.assetOut.chainAssetId == edge.origin else {
            return nil
        }
        
        guard let newAssetOut = host.chain.chainAsset(for: edge.destination.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: edge.destination.assetId)
        }

        return HydraExchangeMetaOperation(
            assetIn: currentOperation.assetIn,
            assetOut: newAssetOut,
            amountIn: hydraOperation.amountIn,
            amountOut: amountOut
        )
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
            feeAsset: feeAsset
        )
    }
}
