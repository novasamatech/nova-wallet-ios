import Foundation
import Operation_iOS

final class CrosschainAssetsExchange {
    let allChains: IndexedChainModels
    let transfers: XcmTransfers

    init(allChains: IndexedChainModels, transfers: XcmTransfers) {
        self.allChains = allChains
        self.transfers = transfers
    }

    private func createExchange(from origin: ChainAssetId, destination: ChainAssetId) -> CrosschainExchangeEdge? {
        .init(origin: origin, destination: destination)
    }
}

extension CrosschainAssetsExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let operation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            self.transfers.chains.flatMap { xcmChain in
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
