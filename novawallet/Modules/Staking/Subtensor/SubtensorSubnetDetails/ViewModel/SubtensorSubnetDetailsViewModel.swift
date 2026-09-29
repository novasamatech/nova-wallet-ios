import Foundation

enum SubtensorSubnetHistoryState: Equatable {
    case loading
    case available(SubtensorPriceHistory)
    case notListed
    case failed
}

enum SubtensorSubnetListingState: Equatable {
    case loading
    case listed(since: Date?)
    case notListed
    case failed
}

enum SubtensorSubnetValidatorState: Equatable {
    case pending
    case selected(SubtensorValidatorDirectoryItem)
    case unselected

    var item: SubtensorValidatorDirectoryItem? {
        guard case let .selected(item) = self else {
            return nil
        }

        return item
    }
}

enum SubtensorSubnetAmountChip: Equatable {
    case fixed(Decimal)
    case max
}

struct SubtensorSubnetDetailsState {
    let isFiat: Bool
    let period: SubtensorPricePeriod
    let history: SubtensorSubnetHistoryState
    let listing: SubtensorSubnetListingState
    let isRankingLoaded: Bool
    let rankingView: SubtensorRankedSubnets?
    let validator: SubtensorSubnetValidatorState
    let isYieldsLoaded: Bool
    let yields: SubtensorAlphaYields?
    let amount: SubtensorSubnetAmountChip
    let transferable: Balance?
    let taoPrice: PriceData?
    let isFavorite: Bool
    let now: Date
}

struct SubtensorSubnetDetailsTitleViewModel {
    let title: String
    let icon: ImageViewModelProtocol
}

struct SubtensorSubnetPriceHeaderViewModel: Equatable {
    enum Change: Equatable {
        case loading
        case hidden
        case value(text: String, isRising: Bool)
    }

    let caption: String
    let price: String
    let change: Change
    let currencies: [String]
    let selectedCurrencyIndex: Int
    let isCurrencyEnabled: Bool
}

enum SubtensorSubnetChartViewModel: Equatable {
    case loading
    case chart(SubtensorPriceChartViewModel)
    case unavailable(title: String, details: String)
    case failed(title: String, action: String)
}

struct SubtensorSubnetPeriodsViewModel: Equatable {
    let titles: [String]
    let selectedIndex: Int
    let isEnabled: Bool
}

enum SubtensorSubnetValidatorRowViewModel {
    case loading
    case unselected(String)
    case selected(name: String, icon: ImageViewModelProtocol?, apy: String?)
}

struct SubtensorSubnetEstimateViewModel: Equatable {
    enum Earnings: Equatable {
        case loading
        case hidden
        case value(String)
    }

    let chips: [String]
    let selectedChipIndex: Int
    let isMaxEnabled: Bool
    let hold: String?
    let earnings: Earnings
}

struct SubtensorSubnetFactorRowViewModel: Equatable {
    enum Value: Equatable {
        case loading
        case safer(String)
        case riskier(String)
        case unknown(String)
    }

    let title: String
    let caption: String
    let value: Value
}

struct SubtensorSubnetFactorsViewModel: Equatable {
    let heading: String?
    let rows: [SubtensorSubnetFactorRowViewModel]
    let footer: String?
    let reasons: String?
    let freshness: String?
}

struct SubtensorSubnetDetailsViewModel {
    let header: SubtensorSubnetPriceHeaderViewModel
    let chart: SubtensorSubnetChartViewModel
    let periods: SubtensorSubnetPeriodsViewModel
    let validator: SubtensorSubnetValidatorRowViewModel
    let estimate: SubtensorSubnetEstimateViewModel
    let factors: SubtensorSubnetFactorsViewModel
    let subnetNumber: String
    let isFavorite: Bool
    let favoriteAccessibilityLabel: String
    let isUseEnabled: Bool
}
