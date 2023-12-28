import Foundation
import BigInt

enum NftDetailsLabel {
    case limited(serialNumber: UInt32, totalIssuance: BigUInt)
    case unlimited
    case fungible(amount: BigUInt, totalSupply: BigUInt)
    case custom(string: String)
}
