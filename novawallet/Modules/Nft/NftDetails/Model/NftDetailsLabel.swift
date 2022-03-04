import Foundation

enum NftDetailsLabel {
    case limited(serialNumber: UInt32, totalIssuance: UInt32)
    case unlimited
    case custom(string: String)
}
