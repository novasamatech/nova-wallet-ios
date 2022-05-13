import Foundation
import SubstrateSdk
import BigInt

extension ParachainStaking {
    struct Delegator: Codable, Equatable {
        let delegations: [ParachainStaking.Bond]
        @StringCodable var total: BigUInt
        @StringCodable var lessTotal: BigUInt
    }

    struct ScheduledRequest: Codable, Equatable {
        @StringCodable var whenExecutable: RoundIndex
    }
}
