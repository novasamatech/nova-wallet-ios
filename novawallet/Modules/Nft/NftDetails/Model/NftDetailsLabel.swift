import Foundation
import BigInt

enum NftDetailsLabel {
    case limited(serialNumber: UInt32, totalIssuance: BigUInt)
    case unlimited
    case custom(string: String)
}
