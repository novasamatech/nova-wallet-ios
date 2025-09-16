import Foundation

extension XcmUnweightedTransferRequest {
    func isTeleport() -> Bool {
        let systemToRelay = origin.parachainId.isSystemParachain && destination.parachainId.isRelay
        let relayToSystem = origin.parachainId.isRelay && destination.parachainId.isSystemParachain
        let systemToSystem = origin.parachainId.isSystemParachain && destination.parachainId.isSystemParachain

        return systemToRelay || relayToSystem || systemToSystem || metadata.usesTeleport
    }

    func deriveXcmTransferType() -> Xcm.TransferTypeWithRelativeLocation {
        if isTeleport() {
            .teleport
        } else if origin.chainAsset.chainAssetId.chainId == reserve.chain.chainId {
            .localReserve
        } else if destination.chain.chainId == reserve.chain.chainId {
            .destinationReserve
        } else {
            .remoteReserve(
                XcmUni.AbsoluteLocation(
                    paraId: reserve.parachainId
                ).fromChainPointOfView(
                    origin.parachainId
                )
            )
        }
    }
}
