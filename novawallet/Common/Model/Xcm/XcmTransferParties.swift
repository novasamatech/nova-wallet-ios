import Foundation

struct XcmTransferParties {
    let origin: ChainAsset
    let destination: XcmTransferDestination
    let reserve: XcmTransferReserve
}
