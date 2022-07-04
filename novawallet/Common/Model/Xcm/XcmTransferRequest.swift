import Foundation
import BigInt

struct XcmTransferRequest {
    let unweighted: XcmUnweightedTransferRequest
    let maxWeight: BigUInt
}
