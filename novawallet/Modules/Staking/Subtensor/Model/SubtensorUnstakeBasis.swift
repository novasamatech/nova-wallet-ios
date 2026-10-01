import Foundation

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
