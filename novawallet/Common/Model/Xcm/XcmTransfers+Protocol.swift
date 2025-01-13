import Foundation

extension XcmTransfers: XcmTransfersProtocol {
    func getAssetTransfer(
        from chainAssetId: ChainAssetId,
        destinationChainId: ChainModel.Id
    ) -> XcmAssetTransferProtocol? {
        transfer(from: chainAssetId, destinationChainId: destinationChainId)
    }
}

extension XcmAssetTransfer: XcmAssetTransferProtocol {}
