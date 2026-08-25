import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct RootBasketPosition: Decodable, Equatable {
        let hotkey: AccountId
        let owedShares: UInt64
        let payout: Balance

        init(hotkey: AccountId, owedShares: UInt64, payout: Balance) {
            self.hotkey = hotkey
            self.owedShares = owedShares
            self.payout = payout
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            hotkey = try container.decode(BytesCodable.self).wrappedValue
            owedShares = try container.decode(StringScaleMapper<UInt64>.self).value
            payout = try container.decode(StringScaleMapper<Balance>.self).value
        }
    }
}
