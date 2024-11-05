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

    func shouldIgnoreFeeRequirement(after predecessor: any AssetExchangableGraphEdge) -> Bool {
        predecessor is AssetsHydraExchangeEdge
    }

    func canPayNonNativeFeesInIntermediatePosition() -> Bool {
        // TODO: assetIn must whitelisted for fee payment

        true
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
