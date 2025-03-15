import Foundation

extension XcmLegacyTransfers: XcmTransfersProtocol {
    func getAssetTransfer(
        from chainAssetId: ChainAssetId,
        destinationChainId: ChainModel.Id
    ) -> XcmAssetTransferProtocol? {
        transfer(from: chainAssetId, destinationChainId: destinationChainId)
    }

    func getAssetReservePath(for chainAsset: ChainAsset) -> XcmAsset.ReservePath? {
        getReservePath(for: chainAsset.chainAssetId)
    }
}

extension XcmAssetTransfer: XcmAssetTransferProtocol {}
