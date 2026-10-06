import BigInt
import Foundation

enum SubtensorPortfolioBuilder {
    static func build(
        state: Multistaking.SubtensorStakingState,
        catalogue: SubtensorSubnetCatalogue? = nil
    ) -> SubtensorPortfolio {
        let positionsByNetuid = Dictionary(grouping: state.positions, by: \.netuid)

        let root = positionsByNetuid[SubtensorStakingPallet.rootNetuid].flatMap { positions in
            buildGroup(
                netuid: SubtensorStakingPallet.rootNetuid,
                positions: positions,
                state: state,
                catalogue: catalogue
            )
        }

        let subnets = positionsByNetuid
            .filter { $0.key != SubtensorStakingPallet.rootNetuid }
            .compactMap { buildGroup(netuid: $0.key, positions: $0.value, state: state, catalogue: catalogue) }
            .sorted(by: isOrderedBefore)

        let pricedTaoValue = ([root].compactMap { $0 } + subnets).reduce(Balance.zero) { total, group in
            total + (group.taoValue ?? .zero)
        }

        let unpricedNetuids = Set(subnets.filter { $0.taoValue == nil }.map(\.netuid))

        return SubtensorPortfolio(
            root: root,
            subnets: subnets,
            pricedTaoValue: pricedTaoValue,
            unpricedNetuids: unpricedNetuids
        )
    }
}

private extension SubtensorPortfolioBuilder {
    static func buildGroup(
        netuid: UInt16,
        positions: [SubtensorStakingPosition],
        state: Multistaking.SubtensorStakingState,
        catalogue: SubtensorSubnetCatalogue?
    ) -> SubtensorPortfolioGroup? {
        let members = positions.sorted(by: isMemberOrderedBefore)

        guard let primary = members.first else {
            return nil
        }

        let totalAlpha = members.reduce(Balance.zero) { $0 + $1.stakeAlpha }

        let taoValue = netuid == SubtensorStakingPallet.rootNetuid
            ? totalAlpha
            : catalogue?.taoValue(of: totalAlpha, netuid: netuid)

        return SubtensorPortfolioGroup(
            netuid: netuid,
            positions: members,
            totalAlpha: totalAlpha,
            taoValue: taoValue,
            availability: state.availability[netuid],
            primaryHotkey: primary.hotkey
        )
    }

    static func isMemberOrderedBefore(_ lhs: SubtensorStakingPosition, _ rhs: SubtensorStakingPosition) -> Bool {
        guard lhs.stakeAlpha == rhs.stakeAlpha else {
            return lhs.stakeAlpha > rhs.stakeAlpha
        }

        return lhs.hotkey.lexicographicallyPrecedes(rhs.hotkey)
    }

    static func isOrderedBefore(_ lhs: SubtensorPortfolioGroup, _ rhs: SubtensorPortfolioGroup) -> Bool {
        switch (lhs.taoValue, rhs.taoValue) {
        case let (.some(lhsValue), .some(rhsValue)) where lhsValue != rhsValue:
            return lhsValue > rhsValue
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return lhs.netuid < rhs.netuid
        }
    }
}
