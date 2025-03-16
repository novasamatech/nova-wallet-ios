import Foundation

struct XcmTransfersResult {
    let legacy: XcmLegacyTransfers
    let dynamic: XcmDynamicTransfers
}

enum XcmTransfers {
    case legacy(XcmLegacyTransfers)
    case dynamic(XcmDynamicTransfers)
}

extension XcmTransfers: XcmTransfersProtocol {
    func getAssetTransfer(
        from chainAssetId: ChainAssetId,
        destinationChainId: ChainModel.Id
    ) -> XcmAssetTransferProtocol? {
        switch self {
        case let .legacy(legacyTransfers):
            legacyTransfers.getAssetTransfer(
                from: chainAssetId,
                destinationChainId: destinationChainId
            )
        case let .dynamic(dynamicTransfers):
            dynamicTransfers.getAssetTransfer(
                from: chainAssetId,
                destinationChainId: destinationChainId
            )
        }
    }

    func getAssetReservePath(for chainAsset: ChainAsset) -> XcmAsset.ReservePath? {
        switch self {
        case let .legacy(legacyTransfers):
            legacyTransfers.getAssetReservePath(for: chainAsset)
        case let .dynamic(dynamicTransfers):
            dynamicTransfers.getAssetReservePath(for: chainAsset)
        }
    }
}
