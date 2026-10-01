import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct RootBasketPosition: Decodable, Equatable {
        let hotkey: AccountId
        let owedShares: UInt64
        let payout: Balance

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            hotkey = try container.decode(BytesCodable.self).wrappedValue
            owedShares = try container.decode(StringScaleMapper<UInt64>.self).value
            payout = try container.decode(StringScaleMapper<Balance>.self).value
        }
    }
}
