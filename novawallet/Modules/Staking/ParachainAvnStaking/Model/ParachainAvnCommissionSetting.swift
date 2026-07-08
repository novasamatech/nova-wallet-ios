import Foundation
import SubstrateSdk
import BigInt

extension ParachainAvn {
    /// EWX `DefaultCollatorCommission` storage value.
    ///
    /// Shape: `{ current: Perbill, scheduled: Option<Perbill> }`.
    /// `current` is the active collator commission (10% = 100_000_000 on
    /// mainnet). `scheduled` is set when governance has voted in a new
    /// commission that takes effect at the next era boundary.
    ///
    /// Moonbeam stores `CollatorCommission` as a bare `Perbill` (4 bytes)
    /// — that's why this CommissionSetting value (5+ bytes) cannot be
    /// decoded as `BigUInt` via `getCollatorCommissionProvider`.
    struct CommissionSetting: Decodable, Equatable {
        let current: BigUInt
        let scheduled: BigUInt?

        private enum CodingKeys: String, CodingKey {
            case current
            case scheduled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            current = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .current).value

            // `decodeIfPresent` correctly maps both an absent key and a
            // JSON-`null` value (SubstrateSdk's representation of `Option<T>`
            // when the option is `None`) to nil while still propagating real
            // type-mismatch errors. A `try?` here would silently swallow
            // those errors and mask real runtime/encoder changes.
            scheduled = try container.decodeIfPresent(
                StringScaleMapper<BigUInt>.self, forKey: .scheduled
            )?.value
        }

        init(current: BigUInt, scheduled: BigUInt? = nil) {
            self.current = current
            self.scheduled = scheduled
        }
    }
}
