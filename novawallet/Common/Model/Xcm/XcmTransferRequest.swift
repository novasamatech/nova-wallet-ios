import Foundation
import BigInt

struct XcmTransferRequest {
    let origin: ChainAsset
    let destination: XcmAssetDestination
    let reserve: XcmAssetReserve
    let amount: BigUInt

    var isNonReserveTransfer: Bool {
        reserve.chain.chainId != origin.chain.chainId && reserve.chain.chainId != destination.chain.chainId
    }
}
