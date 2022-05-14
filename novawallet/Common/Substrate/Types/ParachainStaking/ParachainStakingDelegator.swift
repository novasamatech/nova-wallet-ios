import Foundation
import SubstrateSdk
import BigInt

extension ParachainStaking {
    struct Delegator: Codable, Equatable {
        let delegations: [ParachainStaking.Bond]
        @StringCodable var total: BigUInt
        @StringCodable var lessTotal: BigUInt

        var staked: BigUInt {
            total >= lessTotal ? total - lessTotal : 0
        }
    }

    struct ScheduledRequest: Codable, Equatable {
        @StringCodable var whenExecutable: RoundIndex
    }
}
