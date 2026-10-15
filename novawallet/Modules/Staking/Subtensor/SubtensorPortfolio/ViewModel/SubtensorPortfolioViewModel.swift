import Foundation

enum SubtensorPortfolioPriceState: Equatable {
    case loading
    case loaded(PriceData?)

    var value: PriceData? {
        guard case let .loaded(price) = self else {
            return nil
        }

        return price
    }
}

enum SubtensorPortfolioHistoriesState: Equatable {
    case loading
    case loaded(SubtensorPortfolioPriceHistories)
    case failed
}

struct SubtensorPortfolioState {
    var positions: Multistaking.SubtensorStakingState?
    var isSyncFailed = false
    var price = SubtensorPortfolioPriceState.loading
    var isCatalogueResolved = false
    var catalogue: SubtensorSubnetCatalogue?
    var subnetLogos: SubtensorSubnetLogos?
    var rootYields: SubtensorAlphaYields?
    var isRootRateResolved = false
    var networkRootRate: Decimal?
    var weeklyChanges: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>] = [:]
    var histories = SubtensorPortfolioHistoriesState.loading {
        didSet {
            chartPoint = nil
        }
    }

    var period = SubtensorPortfolioViewModelFactory.defaultPeriod
    var chartPoint: Int?

    var portfolio: SubtensorPortfolio? {
        positions.map { SubtensorPortfolioBuilder.build(state: $0, catalogue: catalogue) }
    }

    var groups: [SubtensorPortfolioGroup] {
        guard let portfolio else {
            return []
        }

        return ([portfolio.root].compactMap { $0 } + portfolio.subnets).filter { group in
            group.totalAlpha > 0 || group.redeemable > 0
        }
    }

    var isValuationPending: Bool {
        !isCatalogueResolved && groups.contains { $0.netuid != SubtensorStakingPallet.rootNetuid }
    }

    var subnetRefs: [SubtensorSubnetRef] {
        guard isCatalogueResolved, let portfolio else {
            return []
        }

        return portfolio.subnets
            .compactMap { catalogue?.subnet(for: $0.netuid)?.ref }
            .sorted { $0.netuid < $1.netuid }
    }

    var isRootRateUnavailable: Bool {
        isRootRateResolved && rootYields == nil && groups.contains { $0.netuid == SubtensorStakingPallet.rootNetuid }
    }

    var isCatalogueUnavailable: Bool {
        let heldNetuids = groups.map(\.netuid).filter { $0 != SubtensorStakingPallet.rootNetuid }

        guard isCatalogueResolved, !heldNetuids.isEmpty else {
            return false
        }

        guard let catalogue else {
            return true
        }

        return heldNetuids.contains { catalogue.subnet(for: $0)?.pricesStamp.freshness == .stale }
    }
}

struct SubtensorPortfolioChangeViewModel: Equatable {
    let text: String
    let isRising: Bool
}

enum SubtensorPortfolioChartViewModel: Equatable {
    case loading
    case chart(SubtensorPriceChartViewModel)
    case unavailable(String)
    case hidden
}

struct SubtensorPortfolioPeriodsViewModel: Equatable {
    let titles: [String]
    let selectedIndex: Int
}

struct SubtensorPortfolioHeaderViewModel: Equatable {
    let total: String?
    let fiat: SubtensorRowState<String>
    let change: SubtensorRowState<SubtensorPortfolioChangeViewModel>
    let chart: SubtensorPortfolioChartViewModel
    let periods: SubtensorPortfolioPeriodsViewModel
}

struct SubtensorPortfolioRowViewModel {
    enum Detail: Equatable {
        case fiat(String)
        case change(SubtensorPortfolioChangeViewModel)
    }

    let icon: ImageViewModelProtocol
    let title: String
    let subtitle: String?
    let value: String
    let symbol: String
    let detail: Detail?
}

struct SubtensorPortfolioEmptyViewModel: Equatable {
    let total: String
    let fiat: String?
    let rootSubtitle: String
}

enum SubtensorPortfolioContentViewModel {
    case positions(
        header: SubtensorPortfolioHeaderViewModel,
        rows: [SubtensorPortfolioRowViewModel],
        loadingRows: Int = 0
    )
    case empty(SubtensorPortfolioEmptyViewModel)
}

struct SubtensorPortfolioViewModel {
    let content: SubtensorPortfolioContentViewModel
    let isSyncFailed: Bool
    let isRatesUnavailable: Bool
}
