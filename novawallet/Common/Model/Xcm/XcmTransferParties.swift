import Foundation

struct XcmTransferParties {
    let origin: XcmTransferOrigin
    let destination: XcmTransferDestination
    let reserve: XcmTransferReserve
    let metadata: XcmTransferMetadata

    var originChain: ChainModel {
        origin.chainAsset.chain
    }

    var reserveChain: ChainModel {
        reserve.chain
    }

    var destinationChain: ChainModel {
        destination.chain
    }
}
