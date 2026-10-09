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
    let yields: SubtensorAlphaYields?
    let amount: SubtensorSubnetAmountChip
    let transferable: Balance?
    let taoPrice: PriceData?
    let isFavorite: Bool
    let now: Date
    let chartPoint: Int?
}

struct SubtensorSubnetDetailsTitleViewModel {
    let title: String
    let icon: ImageViewModelProtocol
}

enum SubtensorSubnetValidatorRowViewModel {
    case loading
    case unselected(String)
    case selected(name: String, icon: ImageViewModelProtocol?, apy: String?)
}

struct SubtensorSubnetEstimateViewModel: Equatable {
    let chips: [String]
    let selectedChipIndex: Int
    let isMaxEnabled: Bool
    let hold: String?
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
    let priceWidget: SubtensorPriceWidgetViewModel
    let validator: SubtensorSubnetValidatorRowViewModel
    let estimate: SubtensorSubnetEstimateViewModel
    let factors: SubtensorSubnetFactorsViewModel
    let subnetNumber: String
    let isFavorite: Bool
    let favoriteAccessibilityLabel: String
    let isUseEnabled: Bool
}
