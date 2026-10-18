import Foundation

struct SubtensorGroupUnstakeBasis: Equatable {
    let total: Balance
    let available: Balance
    let positions: [SubtensorUnstakeSlice]

    var locked: Balance {
        total > available ? total - available : 0
    }

    var hotkeys: [AccountId] {
        positions.map(\.hotkey)
    }

    var drawable: Balance {
        positions.reduce(0) { $0 + $1.alpha }
    }

    var max: Balance {
        min(available, drawable)
    }

    var canExitAll: Bool {
        available >= total && drawable == total
    }

    func position(of hotkey: AccountId) -> Balance? {
        positions.first { $0.hotkey == hotkey }?.alpha
    }

    func plan(for amount: Balance, floor: Balance) -> SubtensorUnstakePlan? {
        guard amount > 0, amount <= max else {
            return nil
        }

        if let primary = positions.first, amount <= primary.alpha, amount < drawable {
            return SubtensorUnstakePlan(
                exits: [],
                partial: SubtensorUnstakeSlice(hotkey: primary.hotkey, alpha: amount)
            )
        }

        var exits: [SubtensorUnstakeSlice] = []
        var needed = amount

        for position in positions.reversed() where needed > 0 {
            guard needed < position.alpha else {
                exits.append(position)
                needed -= position.alpha
                continue
            }

            return adjustedPlan(exits: exits, position: position, needed: needed, floor: floor)
        }

        return SubtensorUnstakePlan(exits: exits, partial: nil)
    }
}

private extension SubtensorGroupUnstakeBasis {
    func adjustedPlan(
        exits: [SubtensorUnstakeSlice],
        position: SubtensorUnstakeSlice,
        needed: Balance,
        floor: Balance
    ) -> SubtensorUnstakePlan {
        let exited = exits.reduce(0) { $0 + $1.alpha }

        func fits(_ slice: Balance) -> Bool {
            slice == 0 || slice == position.alpha || (slice >= floor && position.alpha - slice >= floor)
        }

        let candidates = [needed, 0, floor, position.alpha.subtractOrZero(floor), position.alpha]
            .filter { $0 <= position.alpha && exited + $0 <= max && fits($0) }

        let slice = candidates.min { lhs, rhs in
            let lhsDistance = lhs > needed ? lhs - needed : needed - lhs
            let rhsDistance = rhs > needed ? rhs - needed : needed - rhs

            return lhsDistance != rhsDistance ? lhsDistance < rhsDistance : lhs < rhs
        } ?? 0

        switch slice {
        case 0:
            return SubtensorUnstakePlan(exits: exits, partial: nil)
        case position.alpha:
            return SubtensorUnstakePlan(exits: exits + [position], partial: nil)
        default:
            return SubtensorUnstakePlan(
                exits: exits,
                partial: SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: slice)
            )
        }
    }
}

extension SubtensorGroupUnstakeBasis {
    static func make(
        from group: SubtensorPortfolioGroup,
        excluding heldHotkeys: Set<AccountId> = []
    ) -> SubtensorGroupUnstakeBasis {
        let total = group.totalAlpha
        let available = group.availability.map { min(total, $0.available) } ?? total

        let positions = group.positions
            .filter { !heldHotkeys.contains($0.hotkey) }
            .map { SubtensorUnstakeSlice(hotkey: $0.hotkey, alpha: $0.stakeAlpha) }

        return SubtensorGroupUnstakeBasis(total: total, available: available, positions: positions)
    }

    static func floorAlpha(minTao: Balance, price: Balance) -> Balance {
        guard price > 0 else {
            return 0
        }

        return (minTao * SubtensorStakingPallet.alphaPriceScale + price - 1) / price
    }
}
