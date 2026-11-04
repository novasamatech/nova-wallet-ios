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
    var period = SubtensorPriceWidgetViewModelFactory.defaultPeriod
    var history: SubtensorSubnetHistoryState = .loading {
        didSet {
            chartSelection = nil
        }
    }

    var parameters: SubtensorSubnetParameters?
    var isParametersLoaded = false
    var validator: SubtensorSubnetValidatorState
    var yields: SubtensorAlphaYields?
    var isRateResolved = false
    var taoPrice: PriceData?
    var isFavorite = false
    var now = Date()
    var chartEndDate = Date()
    var chartSelection: SubtensorPriceChartSelection?
}

struct SubtensorSubnetDetailsTitleViewModel {
    let title: String
    let icon: ImageViewModelProtocol
}

struct SubtensorParameterRowViewModel {
    let title: String
    let value: String?
    let detail: String?
    let link: URL?

    init(title: String, value: String?, detail: String?, link: URL? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
        self.link = link
    }
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
