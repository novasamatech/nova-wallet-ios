import Foundation
import BigInt

struct XcmTransferRequest {
    let unweighted: XcmUnweightedTransferRequest
    let originFeeAsset: ChainAssetId?

    init(
        unweighted: XcmUnweightedTransferRequest,
        originFeeAsset: ChainAssetId? = nil
    ) {
        self.unweighted = unweighted
        self.originFeeAsset = originFeeAsset
    }
}
