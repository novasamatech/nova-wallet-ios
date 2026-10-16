import Foundation

struct SubtensorPortfolioGroup: Equatable {
    let netuid: UInt16
    let positions: [SubtensorStakingPosition]
    let totalAlpha: Balance
    let redeemable: Balance
    let taoValue: Balance?
    let availability: SubtensorStakingPallet.StakeAvailability?
    let primaryHotkey: AccountId
}

struct SubtensorPortfolio: Equatable {
    let root: SubtensorPortfolioGroup?
    let subnets: [SubtensorPortfolioGroup]
    let pricedTaoValue: Balance
    let unpricedNetuids: Set<UInt16>

    var stakedRoot: SubtensorPortfolioGroup? {
        root.flatMap { $0.positions.isEmpty ? nil : $0 }
    }

    var isFullyPriced: Bool {
        !subnets.contains { $0.totalAlpha > 0 && $0.taoValue == nil }
    }

    func group(netuid: UInt16) -> SubtensorPortfolioGroup? {
        netuid == SubtensorStakingPallet.rootNetuid ? stakedRoot : subnets.first { $0.netuid == netuid }
    }
}

struct SubtensorRootHold: Equatable {
    let interval: UInt64
    let lastStakeBlock: UInt64
}

struct SubtensorRootClaimPreview: Equatable {
    let hotkey: AccountId
    let redeemable: Balance
    let forfeitedEstimate: Balance
    let minimumClaim: Balance
}
