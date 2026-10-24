import BigInt
import Foundation

struct SubtensorUnstakeFloors: Equatable {
    let yield: Balance
    let sweep: Balance
    var exit: Balance = 0

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

    func isDust(floors: SubtensorUnstakeFloors) -> Bool {
        locked == 0 && alpha < floors.exit
    }

    func drawable(floors: SubtensorUnstakeFloors) -> Balance {
        guard locked > 0 else {
            return isDust(floors: floors) ? 0 : alpha
        }

        return free >= floors.yield ? free : 0
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

    func drawable(floors: SubtensorUnstakeFloors) -> Balance {
        positions.reduce(0) { $0 + $1.drawable(floors: floors) }
    }

    func max(floors: SubtensorUnstakeFloors) -> Balance {
        min(available, drawable(floors: floors))
    }

    func plan(for amount: Balance, floors: SubtensorUnstakeFloors) -> SubtensorUnstakePlan? {
        let sellable = positions.filter { !$0.isDust(floors: floors) }

        guard amount > 0, amount <= max(floors: floors), let primary = sellable.first else {
            return nil
        }

        if primary.locked == 0, amount == primary.alpha {
            return SubtensorUnstakePlan(
                exits: [SubtensorUnstakeSlice(hotkey: primary.hotkey, alpha: amount)],
                partials: []
            )
        }

        if sellable.count == 1 || primaryCovers(amount, primary: primary, floors: floors) {
            return SubtensorUnstakePlan(
                exits: [],
                partials: [SubtensorUnstakeSlice(hotkey: primary.hotkey, alpha: amount)]
            )
        }

        var exits: [SubtensorUnstakeSlice] = []
        var partials: [SubtensorUnstakeSlice] = []
        var needed = amount

        for position in positions.reversed() where needed > 0 {
            let drawable = position.drawable(floors: floors)

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
    func primaryCovers(
        _ amount: Balance,
        primary: SubtensorUnstakePosition,
        floors: SubtensorUnstakeFloors
    ) -> Bool {
        amount <= primary.free &&
            amount < drawable(floors: floors) &&
            primary.leavesSweepFloor(after: amount, floors: floors)
    }

    func adjustedPlan(
        exits: [SubtensorUnstakeSlice],
        partials: [SubtensorUnstakeSlice],
        position: SubtensorUnstakePosition,
        needed: Balance,
        floors: SubtensorUnstakeFloors
    ) -> SubtensorUnstakePlan? {
        let drawn = (exits + partials).reduce(0) { $0 + $1.alpha }
        let drawable = position.drawable(floors: floors)
        let max = max(floors: floors)

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
        floors: SubtensorUnstakeFloors,
        coldkey: AccountId? = nil
    ) -> SubtensorGroupUnstakeBasis {
        let members = switch selection {
        case let .validator(hotkey):
            group.positions.filter { $0.hotkey == hotkey }
        case .all:
            capLegs(
                of: group.positions.filter { !heldHotkeys.contains($0.hotkey) },
                undrawable: undrawableHotkeys(in: group, groupHotkeys: groupHotkeys, floors: floors)
            )
        }

        return make(from: group, members: members, groupHotkeys: groupHotkeys, coldkey: coldkey)
    }

    static func undrawableHotkeys(
        in group: SubtensorPortfolioGroup,
        groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo]?,
        floors: SubtensorUnstakeFloors
    ) -> Set<AccountId> {
        guard let groupHotkeys else {
            return []
        }

        let positions = make(from: group, groupHotkeys: groupHotkeys).positions

        return Set(positions.filter { $0.drawable(floors: floors) == 0 }.map(\.hotkey))
    }

    static func isLegCapped(_ group: SubtensorPortfolioGroup, excluding unsellableHotkeys: Set<AccountId>) -> Bool {
        group.positions.filter { !unsellableHotkeys.contains($0.hotkey) }.count > maxLegs
    }

    private static func capLegs(of members: [SubtensorPosition], undrawable: Set<AccountId>) -> [SubtensorPosition] {
        let legs = Set(members.filter { !undrawable.contains($0.hotkey) }.prefix(maxLegs).map(\.hotkey))

        return members.filter { legs.contains($0.hotkey) || undrawable.contains($0.hotkey) }
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
    static let minExitTao: Balance = 1

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
