import Foundation
import SubstrateSdk

struct SubstrateConstants {
    static let maxNominations: UInt32 = 16
    static let accountIdLength = 32
    static let ethereumAddressLength = 20
    static let paraIdLength = 4
    static let paraIdType = PrimitiveType.u32.name
    static let maxUnbondingRequests = 32
    static let genericAddressPrefix: UInt16 = 42
    static let unifiedAddressPrefix: UInt16 = 0
}
