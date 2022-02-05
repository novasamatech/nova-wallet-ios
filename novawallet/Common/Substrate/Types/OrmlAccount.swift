import Foundation
import SubstrateSdk
import BigInt

struct OrmlAccount: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var frozen: BigUInt

    var total: BigUInt { free + reserved }
}
