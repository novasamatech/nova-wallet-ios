import Foundation
import Operation_iOS

final class CrosschainAssetsExchange {
    let host: CrosschainExchangeHostProtocol

    init(host: CrosschainExchangeHostProtocol) {
        self.host = host
    }

    private func createExchange(from origin: ChainAssetId, destination: ChainAssetId) -> CrosschainExchangeEdge? {
        .init(origin: origin, destination: destination, host: host)
    }
}

extension CrosschainAssetsExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let operation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            self.host.xcmTransfers.chains.flatMap { xcmChain in
                xcmChain.assets.flatMap { xcmAsset in
                    let origin = ChainAssetId(chainId: xcmChain.chainId, assetId: xcmAsset.assetId)

                    return xcmAsset.xcmTransfers.compactMap { xcmTransfer in
                        let destination = ChainAssetId(
                            chainId: xcmTransfer.destination.chainId,
                            assetId: xcmTransfer.destination.assetId
                        )

                        return self.createExchange(from: origin, destination: destination)
                    }
                }
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
