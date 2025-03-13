import Foundation

extension XcmDynamicTransfers: XcmTransfersProtocol {
    func getAssetTransfer(
        from chainAssetId: ChainAssetId,
        destinationChainId: ChainModel.Id
    ) -> XcmAssetTransferProtocol? {
        transfer(from: chainAssetId, destinationChainId: destinationChainId)
    }

    func getAssetReservePath(for chainAsset: ChainAsset) -> XcmAsset.ReservePath? {
        let chainId = chainAsset.chain.chainId
        let assetIdKey = String(chainAsset.asset.assetId)

        let assetLocationId = reserveIdOverrides[chainId]?[assetIdKey] ?? chainAsset.asset.symbol

        guard let path = assetsLocation[assetLocationId]?.multiLocation else {
            return nil
        }

        // TODO: Clarify whether we need other reserve types
        return XcmAsset.ReservePath(type: .relative, path: path)
    }
}

extension XcmDynamicAssetTransfer: XcmAssetTransferProtocol {
    var type: XcmTransferType {
        // TODO: Clarify how to derive the type
        .xcmpalletTransferAssets
    }
}
