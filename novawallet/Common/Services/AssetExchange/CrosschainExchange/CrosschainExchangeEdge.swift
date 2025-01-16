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

    func requiresOriginKeepAliveOnIntermediatePosition() -> Bool {
        guard
            let chainIn = host.allChains[origin.chainId],
            let chainAssetIn = chainIn.chainAsset(for: origin.assetId) else {
            return false
        }

        return host.fungibilityPreservationProvider.requiresPreservationForCrosschain(
            assetIn: chainAssetIn
        )
    }

    func beginMetaOperation(
        for amountIn: Balance,
        amountOut: Balance
    ) throws -> AssetExchangeMetaOperationProtocol {
        guard let chainIn = host.allChains[origin.chainId] else {
            throw ChainRegistryError.noChain(origin.chainId)
        }

        guard let chainOut = host.allChains[destination.chainId] else {
            throw ChainRegistryError.noChain(destination.chainId)
        }

        guard let assetIn = chainIn.chainAsset(for: origin.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: origin.assetId)
        }

        guard let assetOut = chainOut.chainAsset(for: destination.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: destination.assetId)
        }

        let keepAlive = host.fungibilityPreservationProvider.requiresPreservationForCrosschain(
            assetIn: assetIn
        )

        return CrosschainExchangeMetaOperation(
            assetIn: assetIn,
            assetOut: assetOut,
            amountIn: amountIn,
            amountOut: amountOut,
            requiresOriginAccountKeepAlive: keepAlive
        )
    }

    func appendToMetaOperation(
        _: AssetExchangeMetaOperationProtocol,
        amountIn _: Balance,
        amountOut _: Balance
    ) throws -> AssetExchangeMetaOperationProtocol? {
        nil
    }

    func beginOperationPrototype() throws -> AssetExchangeOperationPrototypeProtocol {
        guard let chainIn = host.allChains[origin.chainId] else {
            throw ChainRegistryError.noChain(origin.chainId)
        }

        guard let chainOut = host.allChains[destination.chainId] else {
            throw ChainRegistryError.noChain(destination.chainId)
        }

        guard let assetIn = chainIn.chainAsset(for: origin.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: origin.assetId)
        }

        guard let assetOut = chainOut.chainAsset(for: destination.assetId) else {
            throw ChainModelFetchError.noAsset(assetId: destination.assetId)
        }

        return CrosschainExchangeOperationPrototype(assetIn: assetIn, assetOut: assetOut, host: host)
    }

    func appendToOperationPrototype(
        _: AssetExchangeOperationPrototypeProtocol
    ) throws -> AssetExchangeOperationPrototypeProtocol? {
        nil
    }
}
