import Foundation

struct XcmTransfersResult {
    let legacyTransfersResult: Result<XcmLegacyTransfers, Error>
    let dynamicTransfersResult: Result<XcmDynamicTransfers, Error>

    func transfersContainingTransfer(
        from originChainAssetId: ChainAssetId,
        destinationAssetId: ChainAssetId
    ) -> Result<XcmTransfers, Error> {
        let optDynamicTransfers = try? dynamicTransfersResult.get()

        if
            let dynamicTransfers = optDynamicTransfers,
            dynamicTransfers.getAssetTransfer(
                from: originChainAssetId,
                destinationChainId: destinationAssetId
            ) != nil {
            return .success(.dynamic(dynamicTransfers))
        }

        return legacyTransfersResult.map { XcmTransfers.legacy($0) }
    }
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
            return dynamicTransfers.getAssetTransfer(
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
