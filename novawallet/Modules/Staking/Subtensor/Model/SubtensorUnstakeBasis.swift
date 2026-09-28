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

struct SubtensorGroupUnstakeBasis: Equatable {
    let total: Balance
    let primaryAlpha: Balance
    let available: Balance
    let hotkeys: [AccountId]

    var locked: Balance {
        total > available ? total - available : 0
    }

    var canExitAll: Bool {
        available >= total
    }

    var partialCap: Balance {
        min(available, primaryAlpha)
    }

    var max: Balance {
        canExitAll ? total : partialCap
    }

    func isExitAll(amount: Balance) -> Bool {
        canExitAll && amount > 0 && amount == total
    }

    func exitHotkeys(for amount: Balance) -> [AccountId]? {
        isExitAll(amount: amount) ? hotkeys : nil
    }
}

extension SubtensorGroupUnstakeBasis {
    static func make(from group: SubtensorPortfolioGroup) -> SubtensorGroupUnstakeBasis {
        let total = group.totalAlpha
        let primaryAlpha = group.positions.first { $0.hotkey == group.primaryHotkey }?.stakeAlpha ?? 0
        let available = group.availability.map { min(total, $0.available) } ?? total
        let otherHotkeys = group.positions.map(\.hotkey).filter { $0 != group.primaryHotkey }

        return SubtensorGroupUnstakeBasis(
            total: total,
            primaryAlpha: primaryAlpha,
            available: available,
            hotkeys: [group.primaryHotkey] + otherHotkeys
        )
    }
}
