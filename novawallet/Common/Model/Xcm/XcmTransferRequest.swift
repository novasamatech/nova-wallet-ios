import Foundation
import BigInt

struct XcmTransferRequest {
    let unweighted: XcmUnweightedTransferRequest
    let maxWeight: BigUInt
    let originFeeAsset: ChainAssetId?

    init(
        unweighted: XcmUnweightedTransferRequest,
        maxWeight: BigUInt,
        originFeeAsset: ChainAssetId? = nil
    ) {
        self.unweighted = unweighted
        self.maxWeight = maxWeight
        self.originFeeAsset = originFeeAsset
    }
}
