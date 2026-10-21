import BigInt
import Foundation

struct SubtensorUnstakeFloors: Equatable {
    let yield: Balance
    let sweep: Balance

    static let none = SubtensorUnstakeFloors(yield: 0, sweep: 0)
}

struct SubtensorUnstakePosition: Equatable {
    let hotkey: AccountId
    let alpha: Balance
    let locked: Balance
    var isOwned = false

    var free: Balance {
        alpha.subtractOrZero(locked)
    }

    func drawable(floor: Balance) -> Balance {
        guard locked > 0 else {
            return alpha
        }

        return free >= floor ? free : 0
    }

    func leavesSweepFloor(after slice: Balance, floors: SubtensorUnstakeFloors) -> Bool {
        locked > 0 || isOwned || alpha.subtractOrZero(slice) >= floors.sweep
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

    func plan(for amount: Balance, floors: SubtensorUnstakeFloors) -> SubtensorUnstakePlan? {
        guard amount > 0, amount <= max(floor: floors.yield), let primary = positions.first else {
            return nil
        }

        guard positions.count > 1 else {
            return singlePlan(for: amount, position: primary, floor: floors.yield)
        }

        if
            amount <= primary.free,
            amount < drawable(floor: floors.yield),
            primary.leavesSweepFloor(after: amount, floors: floors) {
            return SubtensorUnstakePlan(
                exits: [],
                partials: [SubtensorUnstakeSlice(hotkey: primary.hotkey, alpha: amount)]
            )
        }

        var exits: [SubtensorUnstakeSlice] = []
        var partials: [SubtensorUnstakeSlice] = []
        var needed = amount

        for position in positions.reversed() where needed > 0 {
            let drawable = position.drawable(floor: floors.yield)

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

            return adjustedPlan(exits: exits, partials: partials, position: position, needed: needed, floors: floors)
        }

        return SubtensorUnstakePlan(exits: exits, partials: partials)
    }
}

private extension SubtensorGroupUnstakeBasis {
    func singlePlan(
        for amount: Balance,
        position: SubtensorUnstakePosition,
        floor: Balance
    ) -> SubtensorUnstakePlan {
        guard amount == position.drawable(floor: floor), position.locked == 0 else {
            return SubtensorUnstakePlan(
                exits: [],
                partials: [SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: amount)]
            )
        }

        return SubtensorUnstakePlan(
            exits: [SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: amount)],
            partials: []
        )
    }

    func adjustedPlan(
        exits: [SubtensorUnstakeSlice],
        partials: [SubtensorUnstakeSlice],
        position: SubtensorUnstakePosition,
        needed: Balance,
        floors: SubtensorUnstakeFloors
    ) -> SubtensorUnstakePlan? {
        let drawn = (exits + partials).reduce(0) { $0 + $1.alpha }
        let drawable = position.drawable(floor: floors.yield)
        let max = max(floor: floors.yield)

        func fits(_ slice: Balance) -> Bool {
            guard slice > 0, slice < drawable else {
                return slice > 0 || drawn > 0
            }

            return slice >= floors.yield && position.leavesSweepFloor(after: slice, floors: floors)
        }

        let candidates = [needed, 0, position.free.subtractOrZero(floors.sweep), drawable]
            .filter { $0 <= drawable && drawn + $0 <= max && fits($0) }

        let slice = candidates.min { lhs, rhs in
            let lhsDistance = lhs > needed ? lhs - needed : needed - lhs
            let rhsDistance = rhs > needed ? rhs - needed : needed - rhs

            return lhsDistance != rhsDistance ? lhsDistance < rhsDistance : lhs < rhs
        }

        switch slice {
        case nil:
            return nil
        case 0:
            return SubtensorUnstakePlan(exits: exits, partials: partials)
        case drawable where position.locked == 0:
            return SubtensorUnstakePlan(
                exits: exits + [SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: position.alpha)],
                partials: partials
            )
        case let .some(slice):
            return SubtensorUnstakePlan(
                exits: exits,
                partials: partials + [SubtensorUnstakeSlice(hotkey: position.hotkey, alpha: slice)]
            )
        }
    }
}

extension SubtensorGroupUnstakeBasis {
    static let maxLegs = 16

    static func make(
        from group: SubtensorPortfolioGroup,
        excluding heldHotkeys: Set<AccountId> = [],
        groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo] = [:]
    ) -> SubtensorGroupUnstakeBasis {
        make(
            from: group,
            members: group.positions.filter { !heldHotkeys.contains($0.hotkey) },
            groupHotkeys: groupHotkeys
        )
    }

    static func make(
        from group: SubtensorPortfolioGroup,
        selection: SubtensorUnstakeSelection,
        excluding heldHotkeys: Set<AccountId>,
        groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo],
        coldkey: AccountId? = nil
    ) -> SubtensorGroupUnstakeBasis {
        let members = switch selection {
        case let .validator(hotkey):
            group.positions.filter { $0.hotkey == hotkey }
        case .all:
            Array(group.positions.filter { !heldHotkeys.contains($0.hotkey) }.prefix(maxLegs))
        }

        return make(from: group, members: members, groupHotkeys: groupHotkeys, coldkey: coldkey)
    }

    static func isLegCapped(_ group: SubtensorPortfolioGroup, excluding heldHotkeys: Set<AccountId>) -> Bool {
        group.positions.filter { !heldHotkeys.contains($0.hotkey) }.count > maxLegs
    }

    private static func make(
        from group: SubtensorPortfolioGroup,
        members: [SubtensorPosition],
        groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo],
        coldkey: AccountId? = nil
    ) -> SubtensorGroupUnstakeBasis {
        let total = members.reduce(Balance.zero) { $0 + $1.stakeAlpha }
        let available = group.availability.map { min(total, $0.available) } ?? total

        let positions = members.map {
            SubtensorUnstakePosition(
                hotkey: $0.hotkey,
                alpha: $0.stakeAlpha,
                locked: groupHotkeys[$0.hotkey]?.collateral ?? 0,
                isOwned: coldkey != nil && groupHotkeys[$0.hotkey]?.owner == coldkey
            )
        }

        return SubtensorGroupUnstakeBasis(total: total, available: available, positions: positions)
    }

    static let floorMargin = BigRational.percent(of: 1)

    static func floorAlpha(minTao: Balance, price: Balance, feeRate: UInt16) -> Balance {
        let denominator = BigUInt(SubtensorPallet.perU16Denominator)
        let divisor = price * denominator.subtractOrZero(BigUInt(feeRate))

        guard divisor > 0 else {
            return 0
        }

        let net = minTao * SubtensorPallet.alphaPriceScale * denominator
        let floor = (net + divisor - 1) / divisor
        let margin = (floor * floorMargin.numerator + floorMargin.denominator - 1) / floorMargin.denominator

        return floor + margin
    }
}
