import Foundation
import SubstrateSdk
import BigInt

extension Staking {
    struct Ledger: Decodable, Equatable {
        let stash: Data
        @StringCodable var total: BigUInt
        @StringCodable var active: BigUInt
        let unlocking: [UnlockChunk]
        let claimedRewards: [StringScaleMapper<UInt32>]?

        // Claimed rewards will be removed in favor of ClaimedRewards storage
        let legacyClaimedRewards: [StringScaleMapper<UInt32>]?

        var claimedRewardsOrEmpty: [StringScaleMapper<UInt32>] {
            claimedRewards ?? legacyClaimedRewards ?? []
        }
    }

    struct UnlockChunk: Decodable, Equatable {
        @StringCodable var value: BigUInt
        @StringCodable var era: UInt32
    }
}

extension Staking.Ledger {
    func redeemable(inEra activeEra: UInt32) -> BigUInt {
        unlocking.reduce(BigUInt(0)) { result, item in
            item.era <= activeEra ? (result + item.value) : result
        }
    }

    func unbonding(inEra activeEra: UInt32) -> BigUInt {
        unbondings(inEra: activeEra).reduce(BigUInt(0)) { result, item in
            result + item.value
        }
    }

    func unbondings(inEra activeEra: UInt32) -> [Staking.UnlockChunk] {
        unlocking.filter { $0.era > activeEra }
    }

    func unbonding() -> BigUInt {
        unlocking.reduce(BigUInt(0)) { $0 + $1.value }
    }
}
