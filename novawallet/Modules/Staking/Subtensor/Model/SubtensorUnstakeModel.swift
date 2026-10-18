import Foundation

struct SubtensorUnstakeSlice: Equatable {
    let hotkey: AccountId
    let alpha: Balance
}

struct SubtensorUnstakePlan: Equatable {
    let exits: [SubtensorUnstakeSlice]
    let partial: SubtensorUnstakeSlice?

    var amount: Balance {
        exits.reduce(partial?.alpha ?? 0) { $0 + $1.alpha }
    }

    var hotkeys: [AccountId] {
        exits.map(\.hotkey) + (partial.map { [$0.hotkey] } ?? [])
    }

    var single: SubtensorUnstakeSlice? {
        exits.isEmpty ? partial : nil
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

        guard liveExits.count == exits.count else {
            return nil
        }

        if let partial, (alphas[partial.hotkey] ?? 0) < partial.alpha {
            return nil
        }

        return SubtensorUnstakePlan(exits: liveExits, partial: partial)
    }

    func emptiesGroup(_ group: SubtensorPortfolioGroup) -> Bool {
        partial == nil && Set(group.positions.map(\.hotkey)).isSubset(of: exits.map(\.hotkey))
    }

    func rootOperation(amount: Balance) -> SubtensorStakingOperation {
        guard let single else {
            return .rootUnstakeGroup(exits: exits.map(\.hotkey), partial: partial)
        }

        return .rootUnstake(hotkey: single.hotkey, amount: amount)
    }

    func subnetOperation(netuid: UInt16, limitPrice: Balance, quotedTaoOut: Balance) -> SubtensorStakingOperation {
        guard let single else {
            return .subnetSellGroup(
                exits: exits.map(\.hotkey),
                partial: partial,
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
    let groupHotkeys: [AccountId]

    var amount: Balance {
        plan.amount
    }
}
