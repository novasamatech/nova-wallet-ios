import Foundation

enum SubtensorPositionAction: Equatable {
    case addStake
    case unstake
    case buy
    case sell
}

struct SubtensorPositionState {
    let netuid: UInt16
    var group: SubtensorPortfolioGroup?
    var isSyncFailed = false
    var price = SubtensorPortfolioPriceState.loading
    var isCatalogueResolved = false
    var catalogue: SubtensorSubnetCatalogue?
    var subnetLogos: SubtensorSubnetLogos?
    var validatorHotkey: AccountId?
    var validator: SubtensorValidatorDirectoryItem?
    var isRateResolved = false
    var rootRate: Decimal?
    var yields: SubtensorAlphaYields?
    var claimable: SubtensorRootClaimable?
    var isClaimableFailed = false
    var holds: [AccountId: SubtensorRootHold] = [:]
    var blockNumber: BlockNumber?
    var period = SubtensorPositionViewModelFactory.defaultPeriod
    var history = SubtensorSubnetHistoryState.loading
    var hasResolvedHistory = false

    init(netuid: UInt16, group: SubtensorPortfolioGroup?) {
        self.netuid = netuid
        self.group = group
    }

    var isRoot: Bool {
        netuid == SubtensorStakingPallet.rootNetuid
    }

    var primaryPosition: SubtensorStakingPosition? {
        group.flatMap { group in
            group.positions.first { $0.hotkey == group.primaryHotkey }
        }
    }

    var isValidatorResolved: Bool {
        validatorHotkey != nil && validatorHotkey == group?.primaryHotkey
    }

    var annualRate: Decimal? {
        guard !isRoot else {
            return rootRate
        }

        return group.flatMap { SubtensorAlphaApyFormatter.annualRate(for: $0.primaryHotkey, in: yields) }
    }

    var unstakeBasis: SubtensorGroupUnstakeBasis? {
        group.map { SubtensorGroupUnstakeBasis.make(from: $0) }
    }

    var taoValue: Balance? {
        group.flatMap { catalogue?.taoValue(of: $0.totalAlpha, netuid: netuid) }
    }

    var primaryHold: SubtensorRootHold? {
        group.flatMap { holds[$0.primaryHotkey] }
    }

    var holdRemainingBlocks: UInt64? {
        guard isRoot, let hold = primaryHold, hold.interval > 0, let blockNumber else {
            return nil
        }

        let remaining = hold.remainingBlocks(at: UInt64(blockNumber))

        return remaining > 0 ? remaining : nil
    }

    func isEnabled(_ action: SubtensorPositionAction) -> Bool {
        switch action {
        case .addStake, .unstake:
            return holdRemainingBlocks == nil
        case .buy:
            return true
        case .sell:
            return (unstakeBasis?.available ?? 0) > 0
        }
    }
}

enum SubtensorPositionValueViewModel: Equatable {
    case loading
    case loaded(value: String, detail: String?, isPositive: Bool)
}

struct SubtensorPositionRowViewModel: Equatable {
    let title: String
    let value: SubtensorPositionValueViewModel
}

struct SubtensorPositionSummaryViewModel {
    let icon: ImageViewModelProtocol?
    let caption: String?
    let amount: String?
    let fiat: SubtensorPortfolioLoadable<String>
    let isActive: Bool?
    let rows: [SubtensorPositionRowViewModel]
}

struct SubtensorPositionActionViewModel: Equatable {
    let action: SubtensorPositionAction
    let title: String
    let isEnabled: Bool
}

struct SubtensorPositionValidatorViewModel {
    let icon: ImageViewModelProtocol?
    let name: String?
    let subtitle: String
    let rate: SubtensorPortfolioLoadable<String>
    let rateCaption: String
}

struct SubtensorPositionNoticeViewModel: Equatable {
    let title: String
    let timeLeft: String?
    let message: String
}

struct SubtensorPositionChartViewModel: Equatable {
    let chart: SubtensorSubnetChartViewModel
    let periods: SubtensorSubnetPeriodsViewModel
}

struct SubtensorPositionViewModel {
    let title: String?
    let summary: SubtensorPositionSummaryViewModel
    let chart: SubtensorPositionChartViewModel?
    let actions: [SubtensorPositionActionViewModel]
    let validator: SubtensorPositionValidatorViewModel
    let notice: SubtensorPositionNoticeViewModel?
    let isSyncFailed: Bool
}
