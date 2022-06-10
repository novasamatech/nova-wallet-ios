import Foundation
import SubstrateSdk
import BigInt

struct ValidatorPrefs: Codable, Equatable {
    @StringCodable var commission: BigUInt
    let blocked: Bool?

    var isBlocked: Bool { blocked ?? false }
}
