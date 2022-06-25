import Foundation
import BigInt

struct XcmUnweightedTransferRequest {
    let origin: ChainAsset
    let destination: XcmTransferDestination
    let reserve: XcmTransferReserve
    let amount: BigUInt

    var isNonReserveTransfer: Bool {
        reserve.chain.chainId != origin.chain.chainId && reserve.chain.chainId != destination.chain.chainId
    }
}
