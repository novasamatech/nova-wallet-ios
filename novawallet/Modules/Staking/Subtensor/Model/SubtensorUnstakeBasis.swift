import Foundation

/// What the user may actually move out of one position right now.
///
/// `get_stake_availability_for_coldkeys` reports `available` per (coldkey, netuid) net of the
/// subnet-wide conviction lock and miner collateral (subtensor: `staking/lock.rs:750-759`), so it
/// can be smaller than the single position it is applied to and is clamped by it here. Rows whose
/// total and lock are both zero are omitted from the runtime API response
/// (`rpc_info/stake_info.rs:186-190`), so a missing availability means "no lock", not "nothing free".
struct SubtensorUnstakeBasis: Equatable {
    let staked: Balance
    let available: Balance

    var locked: Balance {
        staked > available ? staked - available : 0
    }

    var isFullyLocked: Bool {
        staked > 0 && available == 0
    }

    var isFullyAvailable: Bool {
        available == staked
    }
}

extension SubtensorUnstakeBasis {
    static func make(
        staked: Balance,
        availability: SubtensorStakingPallet.StakeAvailability?
    ) -> SubtensorUnstakeBasis {
        guard let availability else {
            return SubtensorUnstakeBasis(staked: staked, available: staked)
        }

        return SubtensorUnstakeBasis(staked: staked, available: min(staked, availability.available))
    }
}
