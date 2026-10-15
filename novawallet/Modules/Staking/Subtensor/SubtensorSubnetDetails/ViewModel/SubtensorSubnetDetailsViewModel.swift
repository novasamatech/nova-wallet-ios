import Foundation

enum SubtensorSubnetHistoryState: Equatable {
    case loading
    case available(SubtensorPriceHistory)
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

struct SubtensorSubnetDetailsState {
    let isFiat: Bool
    let period: SubtensorPricePeriod
    let history: SubtensorSubnetHistoryState
    let parameters: SubtensorSubnetParameters?
    let isParametersLoaded: Bool
    let validator: SubtensorSubnetValidatorState
    let yields: SubtensorAlphaYields?
    let taoPrice: PriceData?
    let isFavorite: Bool
    let now: Date
    let chartEndDate: Date
    let chartSelection: SubtensorPriceChartSelection?
}

struct SubtensorSubnetDetailsTitleViewModel {
    let title: String
    let icon: ImageViewModelProtocol
}

struct SubtensorParameterRowViewModel {
    let title: String
    let value: String?
    let detail: String?
}

struct SubtensorSubnetParametersViewModel {
    let split: Decimal?
    let taoTitle: String
    let taoShare: String
    let alphaTitle: String
    let alphaShare: String
    let rows: [SubtensorParameterRowViewModel]
}

struct SubtensorSubnetDetailsViewModel {
    let priceWidget: SubtensorPriceWidgetViewModel
    let validator: SubtensorValidatorCardViewModel
    let parameters: SubtensorSubnetParametersViewModel
    let moreDetails: [SubtensorParameterRowViewModel]
    let isFavorite: Bool
    let favoriteAccessibilityLabel: String
    let isUseEnabled: Bool
}
