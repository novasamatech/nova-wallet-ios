import Foundation

protocol XcmTransfersProtocol {
    func getAssetTransfer(
        from chainAssetId: ChainAssetId,
        destinationChainId: ChainModel.Id
    ) -> XcmAssetTransferProtocol?

    func getAssetReservePath(for chainAsset: ChainAsset) -> XcmAsset.ReservePath?
}

protocol XcmAssetTransferProtocol {
    var type: XcmTransferType { get }
}
