import Foundation
import Operation_iOS

final class CrosschainExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId
    let host: CrosschainExchangeHostProtocol

    init(origin: ChainAssetId, destination: ChainAssetId, host: CrosschainExchangeHostProtocol) {
        self.origin = origin
        self.destination = destination
        self.host = host
    }

    private func deliveryFeeNotPaidOrFromHolding() -> Bool {
        do {
            guard let deliveryFee = try host.xcmTransfers.deliveryFee(from: origin.chainId) else {
                return true
            }

            guard
                let originChain = host.allChains[origin.chainId],
                let destinationChain = host.allChains[destination.chainId] else {
                return false
            }

            if !destinationChain.isRelaychain {
                return deliveryFee.toParachain?.alwaysHoldingPays ?? false
            } else if !originChain.isRelaychain {
                return deliveryFee.toParent?.alwaysHoldingPays ?? false
            } else {
                return false
            }
        } catch {
            return false
        }
    }
}

extension CrosschainExchangeEdge: AssetExchangableGraphEdge {
    var type: AssetExchangeEdgeType { .crossChain }

    var weight: Int { AssetsExchange.defaultEdgeWeight }

    func quote(
        amount: Balance,
        direction _: AssetConversion.Direction
    ) -> CompoundOperationWrapper<Balance> {
        CompoundOperationWrapper.createWithResult(amount)
    }

    func beginOperation(for args: AssetExchangeAtomicOperationArgs) throws -> AssetExchangeAtomicOperationProtocol {
        CrosschainExchangeAtomicOperation(
            host: host,
            edge: self,
            operationArgs: args
        )
    }

    func appendToOperation(
        _: AssetExchangeAtomicOperationProtocol,
        args _: AssetExchangeAtomicOperationArgs
    ) -> AssetExchangeAtomicOperationProtocol? {
        nil
    }

    func shouldIgnoreFeeRequirement(after _: any AssetExchangableGraphEdge) -> Bool {
        false
    }

    func canPayNonNativeFeesInIntermediatePosition() -> Bool {
        deliveryFeeNotPaidOrFromHolding()
    }
}
