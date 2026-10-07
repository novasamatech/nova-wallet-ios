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
}

struct SubtensorRootHold: Equatable {
    let interval: UInt64
    let lastStakeBlock: UInt64
}

struct SubtensorRootClaimPreview: Equatable {
    let hotkey: AccountId
    let accrued: Balance
    let redeemable: Balance
    let forfeitedEstimate: Balance
}
