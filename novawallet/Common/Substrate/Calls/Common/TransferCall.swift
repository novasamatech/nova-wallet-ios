import Foundation
import SubstrateSdk
import BigInt

struct TransferCall: Codable {
    let dest: MultiAddress
    @StringCodable var value: BigUInt
}

struct TransferAllCall: Codable {
    enum CodingKeys: String, CodingKey {
        case dest
        case keepAlive = "keep_alive"
    }

    let dest: MultiAddress
    let keepAlive: Bool
}
