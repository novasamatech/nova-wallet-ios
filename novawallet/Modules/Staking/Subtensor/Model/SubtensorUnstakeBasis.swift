import BigInt
import Foundation

struct SubtensorUnstakePosition: Equatable {
    let hotkey: AccountId
    let alpha: Balance
    let locked: Balance

    var free: Balance {
        alpha.subtractOrZero(locked)
    }

    func drawable(floor: Balance) -> Balance {
        guard locked > 0 else {
            return alpha
        }

        return free >= floor ? free : 0
    }
}

struct SubtensorGroupUnstakeBasis: Equatable {
    let total: Balance
    let available: Balance
    let positions: [SubtensorUnstakePosition]

    var locked: Balance {
        total > available ? total - available : 0
    }

    var hotkeys: [AccountId] {
        positions.map(\.hotkey)
    }

    var canExitAll: Bool {
        available >= total && positions.allSatisfy { $0.locked == 0 } && positions.reduce(0) { $0 + $1.alpha } == total
    }

    func position(of hotkey: AccountId) -> Balance? {
        positions.first { $0.hotkey == hotkey }?.alpha
    }

    func drawable(floor: Balance) -> Balance {
        positions.reduce(0) { $0 + $1.drawable(floor: floor) }
    }

    func max(floor: Balance) -> Balance {
        min(available, drawable(floor: floor))
    }

    func plan(for amount: Balance, floor: Balance) -> SubtensorUnstakePlan? {
        let max = max(floor: floor)

        guard amount > 0, amount <= max else {
            return nil
        }

        if let primary = positions.first, amount <= primary.free, amount < drawable(floor: floor) {
            return SubtensorUnstakePlan(
                exits: [],
                partials: [SubtensorUnstakeSlice(hotkey: primary.hotkey, alpha: amount)]
            )
        }

        var exits: [SubtensorUnstakeSlice] = []
        var partials: [SubtensorUnstakeSlice] = []
        var needed = amount

        for position in positions.reversed() where needed > 0 {
            let drawable = position.drawable(floor: floor)

            guard drawable > 0 else {
                continue
            }

            guard needed < drawable else {
                needed -= drawable

                if position.locked == 0 {
                    exits.append(SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: position.alpha))
                } else {
                    partials.append(SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: drawable))
                }

                continue
            }

            return adjustedPlan(
                exits: exits,
                partials: partials,
                position: position,
                needed: needed,
                floor: floor,
                max: max
            )
        }

        return SubtensorUnstakePlan(exits: exits, partials: partials)
    }
}

private extension SubtensorGroupUnstakeBasis {
    func adjustedPlan(
        exits: [SubtensorUnstakeSlice],
        partials: [SubtensorUnstakeSlice],
        position: SubtensorUnstakePosition,
        needed: Balance,
        floor: Balance,
        max: Balance
    ) -> SubtensorUnstakePlan {
        let drawn = (exits + partials).reduce(0) { $0 + $1.alpha }
        let drawable = position.drawable(floor: floor)

        func fits(_ slice: Balance) -> Bool {
            guard slice > 0, slice < drawable else {
                return true
            }

            return slice >= floor && (position.locked > 0 || position.alpha - slice >= floor)
        }

        let candidates = [needed, 0, position.free.subtractOrZero(floor), drawable]
            .filter { $0 <= drawable && drawn + $0 <= max && fits($0) }

        let slice = candidates.min { lhs, rhs in
            let lhsDistance = lhs > needed ? lhs - needed : needed - lhs
            let rhsDistance = rhs > needed ? rhs - needed : needed - rhs

            return lhsDistance != rhsDistance ? lhsDistance < rhsDistance : lhs < rhs
        } ?? 0

        switch slice {
        case 0:
            return SubtensorUnstakePlan(exits: exits, partials: partials)
        case drawable where position.locked == 0:
            return SubtensorUnstakePlan(
                exits: exits + [SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: position.alpha)],
                partials: partials
            )
        default:
            return SubtensorUnstakePlan(
                exits: exits,
                partials: partials + [SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: slice)]
            )
        }
    }
}

extension SubtensorGroupUnstakeBasis {
    static func make(
        from group: SubtensorPortfolioGroup,
        excluding heldHotkeys: Set<AccountId> = [],
        groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo] = [:]
    ) -> SubtensorGroupUnstakeBasis {
        let total = group.totalAlpha
        let available = group.availability.map { min(total, $0.available) } ?? total

        let positions = group.positions
            .filter { !heldHotkeys.contains($0.hotkey) }
            .map {
                SubtensorUnstakePosition(
                    hotkey: $0.hotkey,
                    alpha: $0.stakeAlpha,
                    locked: groupHotkeys[$0.hotkey]?.collateral ?? 0
                )
            }

        return SubtensorGroupUnstakeBasis(total: total, available: available, positions: positions)
    }

    static let floorMargin = BigRational.percent(of: 1)

    static func floorAlpha(minTao: Balance, price: Balance, feeRate: UInt16) -> Balance {
        let denominator = BigUInt(SubtensorStakingPallet.perU16Denominator)
        let divisor = price * denominator.subtractOrZero(BigUInt(feeRate))

        guard divisor > 0 else {
            return 0
        }

        let net = minTao * SubtensorStakingPallet.alphaPriceScale * denominator
        let floor = (net + divisor - 1) / divisor
        let margin = (floor * floorMargin.numerator + floorMargin.denominator - 1) / floorMargin.denominator

        return floor + margin
    }
}
