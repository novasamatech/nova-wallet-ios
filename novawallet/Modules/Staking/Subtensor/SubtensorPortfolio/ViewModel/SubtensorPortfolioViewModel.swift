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
    var rootRate: Decimal?
    var weeklyChanges: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>] = [:]
    var histories = SubtensorPortfolioHistoriesState.loading
    var period = SubtensorPortfolioViewModelFactory.defaultPeriod

    var portfolio: SubtensorPortfolio? {
        positions.map { SubtensorPortfolioBuilder.build(state: $0, catalogue: catalogue) }
    }

    var groups: [SubtensorPortfolioGroup] {
        guard let portfolio else {
            return []
        }

        return ([portfolio.root].compactMap { $0 } + portfolio.subnets).filter { $0.totalAlpha > 0 }
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
}

enum SubtensorPortfolioLoadable<Value: Equatable>: Equatable {
    case loading
    case hidden
    case loaded(Value)
}

struct SubtensorPortfolioChangeViewModel: Equatable {
    let text: String
    let isRising: Bool
}

enum SubtensorPortfolioChartViewModel: Equatable {
    case loading
    case chart(SubtensorPriceChartViewModel)
    case unavailable(String)
}

struct SubtensorPortfolioPeriodsViewModel: Equatable {
    let titles: [String]
    let selectedIndex: Int
}

struct SubtensorPortfolioHeaderViewModel: Equatable {
    let total: String?
    let fiat: SubtensorPortfolioLoadable<String>
    let change: SubtensorPortfolioLoadable<SubtensorPortfolioChangeViewModel>
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
    let detail: Detail?
}

struct SubtensorPortfolioEmptyViewModel: Equatable {
    let total: String
    let fiat: String?
    let rootSubtitle: String
}

enum SubtensorPortfolioContentViewModel {
    case positions(header: SubtensorPortfolioHeaderViewModel, rows: [SubtensorPortfolioRowViewModel]?)
    case empty(SubtensorPortfolioEmptyViewModel)
}

struct SubtensorPortfolioViewModel {
    let content: SubtensorPortfolioContentViewModel
    let isSyncFailed: Bool
}
