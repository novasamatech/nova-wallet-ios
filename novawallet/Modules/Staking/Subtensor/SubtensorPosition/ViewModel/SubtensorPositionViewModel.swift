import Foundation

enum SubtensorPositionAction: Equatable {
    case claim
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
    var prices: SubtensorAlphaPrices?
    var subnetLogos: SubtensorSubnetLogos?
    var validatorHotkey: AccountId?
    var validator: SubtensorValidatorDirectoryItem?
    var isRateResolved = false
    var yields: SubtensorAlphaYields?
    var costBasis = SubtensorCostBasisState.loading
    var isOwnTradeSettling = false
    var claimable: [SubtensorRootClaimPreview]?
    var isClaimableFailed = false
    var pendingClaimHotkeys: Set<AccountId> = []
    var holds: [AccountId: SubtensorRootHold] = [:]
    var blockNumber: BlockNumber?
    var blockTime: BlockTime?
    var period = SubtensorPriceWidgetViewModelFactory.defaultPeriod
    var history = SubtensorSubnetHistoryState.loading {
        didSet {
            chartSelection = nil
        }
    }

    var hasResolvedHistory = false
    var chartEndDate = Date.distantPast
    var chartSelection: SubtensorPriceChartSelection?

    init(netuid: UInt16, group: SubtensorPortfolioGroup?) {
        self.netuid = netuid
        self.group = group
    }

    var isRoot: Bool {
        netuid == SubtensorPallet.rootNetuid
    }

    var catalogue: SubtensorSubnetCatalogue? {
        prices?.catalogue
    }

    var primaryPosition: SubtensorPosition? {
        group.flatMap { group in
            group.positions.first { $0.hotkey == group.primaryHotkey }
        }
    }

    var isValidatorResolved: Bool {
        validatorHotkey != nil && validatorHotkey == group?.primaryHotkey
    }

    var annualRate: Decimal? {
        group.flatMap { SubtensorAlphaApyFormatter.annualRate(for: $0.primaryHotkey, in: yields) }
    }

    var unstakeBasis: SubtensorGroupUnstakeBasis? {
        group.map { SubtensorGroupUnstakeBasis.make(from: $0) }
    }

    var taoValue: Balance? {
        group.flatMap { prices?.taoValue(of: $0.totalAlpha, netuid: netuid) }
    }

    var worthNow: SubtensorSaleProceeds {
        guard let group, let taoValue else {
            return .unknown
        }

        return .quoted(alpha: group.totalAlpha, tao: taoValue)
    }

    var primaryHold: SubtensorRootHold? {
        group.flatMap { holds[$0.primaryHotkey] }
    }

    var holdRemainingBlocks: UInt64? {
        guard isRoot, let group, let blockNumber else {
            return nil
        }

        let head = UInt64(blockNumber)
        let remaining = group.positions.map { holds[$0.hotkey]?.remainingBlocks(at: head) ?? 0 }

        guard let earliest = remaining.min(), earliest > 0 else {
            return nil
        }

        return earliest
    }

    var claimTarget: SubtensorRootClaimPreview? {
        claimable.flatMap { SubtensorRootClaimRule.target(in: $0, excluding: pendingClaimHotkeys) }
    }

    func isEnabled(_ action: SubtensorPositionAction) -> Bool {
        switch action {
        case .claim:
            return isRoot && !isClaimableFailed && claimTarget != nil
        case .addStake:
            return primaryPosition != nil
        case .unstake:
            return primaryPosition != nil && holdRemainingBlocks == nil
        case .buy:
            return true
        case .sell:
            return (unstakeBasis?.available ?? 0) > 0
        }
    }
}

extension SubtensorPositionState {
    func claimRewardsModel(
        for account: MetaChainAccountResponse,
        chainFormat: ChainFormat
    ) -> SubtensorClaimRewardsModel? {
        guard
            let target = claimTarget,
            let address = try? target.hotkey.toAddress(using: chainFormat) else {
            return nil
        }

        let name = target.hotkey == validatorHotkey ? validator?.name : nil

        return SubtensorClaimRewardsModel(
            account: account,
            validator: SubtensorConfirmValidator(
                hotkey: target.hotkey,
                display: DisplayAddress(address: address, username: name ?? ""),
                annualRate: nil
            ),
            shownPreview: target
        )
    }
}

enum SubtensorPositionValueViewModel: Equatable {
    case loading
    case loaded(value: String, detail: String?)
}

struct SubtensorPositionRowViewModel: Equatable {
    let title: String
    let value: SubtensorPositionValueViewModel
    let caption: String?
    var tone = SubtensorValueTone.neutral
}

struct SubtensorPositionSummaryViewModel {
    let icon: ImageViewModelProtocol?
    let caption: String?
    let amount: String?
    let fiat: SubtensorRowState<String>
    let isActive: Bool?
    let rows: [SubtensorPositionRowViewModel]
}

struct SubtensorPositionActionViewModel: Equatable {
    let action: SubtensorPositionAction
    let title: String
    let isEnabled: Bool
    let details: String?
}

struct SubtensorPositionNoticeViewModel: Equatable {
    let title: String
    let timeLeft: String?
    let message: String
}

struct SubtensorPositionViewModel {
    let title: String?
    let summary: SubtensorPositionSummaryViewModel
    let priceWidget: SubtensorPriceWidgetViewModel?
    let actions: [SubtensorPositionActionViewModel]
    let validator: SubtensorValidatorCardViewModel
    let notice: SubtensorPositionNoticeViewModel?
    let isSyncFailed: Bool
}
