import Foundation
import Operation_iOS

final class CrosschainAssetsExchange {
    let host: CrosschainExchangeHostProtocol

    init(host: CrosschainExchangeHostProtocol) {
        self.host = host
    }
}

private extension CrosschainAssetsExchange {
    func createExchange(
        from origin: ChainAssetId,
        destination: ChainAssetId,
        featuresFactory: XcmTransferFeaturesFactoryProtocol
    ) -> CrosschainExchangeEdge? {
        do {
            let originChain = try host.chainRegistry.getChainOrError(for: origin.chainId)
            let originChainAsset = try originChain.chainAssetOrError(for: origin.assetId)
            let destinationChain = try host.chainRegistry.getChainOrError(for: destination.chainId)

            let metadata = try host.xcmTransfers.getTransferMetadata(
                for: originChainAsset,
                destinationChain: destinationChain
            )

            let features = featuresFactory.createFeatures(for: metadata)

            return CrosschainExchangeEdge(
                origin: origin,
                destination: destination,
                host: host,
                features: features
            )
        } catch {
            host.logger.error("Unexpected error \(error)")
            return nil
        }
    }
}

extension CrosschainAssetsExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let featuresFactory = XcmTransferFeaturesFactory()

        let mapOperation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            let edges = self.host.xcmTransfers.getAllTransfers()
                .map { keyValue in
                    keyValue.value.compactMap { destinationAssetId in
                        self.createExchange(
                            from: keyValue.key,
                            destination: destinationAssetId,
                            featuresFactory: featuresFactory
                        )
                    }
                }
                .flatMap { $0 }
            return edges
        }

        return CompoundOperationWrapper(targetOperation: mapOperation)
    }
}
