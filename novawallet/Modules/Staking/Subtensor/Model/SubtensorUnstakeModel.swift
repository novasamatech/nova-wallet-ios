import Foundation

enum SubtensorUnstakeSelection: Equatable {
    case validator(AccountId)
    case all

    var hotkey: AccountId? {
        if case let .validator(hotkey) = self {
            return hotkey
        }

        return nil
    }

    static func resolve(
        _ requested: SubtensorUnstakeSelection?,
        in group: SubtensorPortfolioGroup,
        excluding heldHotkeys: Set<AccountId>
    ) -> SubtensorUnstakeSelection {
        let sellable = group.positions.map(\.hotkey).filter { !heldHotkeys.contains($0) }
        let fallback = SubtensorUnstakeSelection.validator(sellable.first ?? group.primaryHotkey)

        switch requested {
        case .all, nil:
            return canSellAll(in: group, excluding: heldHotkeys) ? .all : fallback
        case let .validator(hotkey):
            return sellable.contains(hotkey) ? .validator(hotkey) : fallback
        }
    }

    static func canSellAll(in group: SubtensorPortfolioGroup, excluding heldHotkeys: Set<AccountId>) -> Bool {
        group.positions.count > 1 && group.positions.contains { !heldHotkeys.contains($0.hotkey) }
    }
}

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

    func rootOperation(amount: Balance) -> SubtensorOperation {
        guard let single else {
            return .rootUnstakeGroup(exits: exits.map(\.hotkey), partials: partials)
        }

        return .rootUnstake(hotkey: single.hotkey, amount: amount)
    }

    func subnetOperation(
        netuid: UInt16,
        limitPrice: Balance,
        quotedTaoOut: Balance,
        novaFee: SubtensorNovaFee?
    ) -> SubtensorOperation {
        guard let single else {
            return .subnetSellGroup(
                exits: exits.map(\.hotkey),
                partials: partials,
                netuid: netuid,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut,
                novaFee: novaFee
            )
        }

        return .subnetSell(
            hotkey: single.hotkey,
            netuid: netuid,
            alpha: single.alpha,
            limitPrice: limitPrice,
            quotedTaoOut: quotedTaoOut,
            novaFee: novaFee
        )
    }
}

struct SubtensorUnstakeModel {
    let netuid: UInt16
    let plan: SubtensorUnstakePlan
    let groupHotkeys: [AccountId: SubtensorGroupHotkeyInfo]
    var validators: [AccountId: SubtensorConfirmValidator] = [:]

    var amount: Balance {
        plan.amount
    }
}
