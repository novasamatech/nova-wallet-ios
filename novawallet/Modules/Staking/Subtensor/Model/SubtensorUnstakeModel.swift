import Foundation

struct SubtensorUnstakeSlice: Equatable {
    let hotkey: AccountId
    let alpha: Balance
}

struct SubtensorGroupHotkeyInfo: Equatable {
    let owner: AccountId?
    let collateral: Balance
}

struct SubtensorUnstakePlan: Equatable {
    let exits: [SubtensorUnstakeSlice]
    let partials: [SubtensorUnstakeSlice]

    var slices: [SubtensorUnstakeSlice] {
        exits + partials
    }

    var amount: Balance {
        slices.reduce(0) { $0 + $1.alpha }
    }

    var hotkeys: [AccountId] {
        slices.map(\.hotkey)
    }

    var single: SubtensorUnstakeSlice? {
        exits.isEmpty && partials.count == 1 ? partials.first : nil
    }

    var isBatched: Bool {
        hotkeys.count > 1
    }
}

extension SubtensorUnstakePlan {
    func rebuilt(from group: SubtensorPortfolioGroup) -> SubtensorUnstakePlan? {
        let alphas = Dictionary(group.positions.map { ($0.hotkey, $0.stakeAlpha) }) { first, _ in first }

        let liveExits = exits.compactMap { exit in
            alphas[exit.hotkey].map { SubtensorUnstakeSlice(hotkey: exit.hotkey, alpha: $0) }
        }

        guard
            liveExits.count == exits.count,
            partials.allSatisfy({ (alphas[$0.hotkey] ?? 0) >= $0.alpha }) else {
            return nil
        }

        return SubtensorUnstakePlan(exits: liveExits, partials: partials)
    }

    func emptiesGroup(_ group: SubtensorPortfolioGroup) -> Bool {
        partials.isEmpty && Set(group.positions.map(\.hotkey)).isSubset(of: exits.map(\.hotkey))
    }

    func rootOperation(amount: Balance) -> SubtensorStakingOperation {
        guard let single else {
            return .rootUnstakeGroup(exits: exits.map(\.hotkey), partials: partials)
        }

        return .rootUnstake(hotkey: single.hotkey, amount: amount)
    }

    func subnetOperation(netuid: UInt16, limitPrice: Balance, quotedTaoOut: Balance) -> SubtensorStakingOperation {
        guard let single else {
            return .subnetSellGroup(
                exits: exits.map(\.hotkey),
                partials: partials,
                netuid: netuid,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut
            )
        }

        return .subnetSell(
            hotkey: single.hotkey,
            netuid: netuid,
            alpha: single.alpha,
            limitPrice: limitPrice,
            quotedTaoOut: quotedTaoOut
        )
    }
}

struct SubtensorUnstakeModel {
    let netuid: UInt16
    let plan: SubtensorUnstakePlan
    let groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo]

    var amount: Balance {
        plan.amount
    }
}
