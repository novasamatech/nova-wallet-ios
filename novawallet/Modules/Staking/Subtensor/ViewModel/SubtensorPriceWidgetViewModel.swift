import Foundation

struct SubtensorSubnetCurrencyViewModel: Equatable {
    let titles: [String]
    let selectedIndex: Int
    let isEnabled: Bool
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
    let currency: SubtensorSubnetCurrencyViewModel?
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

struct SubtensorPriceWidgetViewModel: Equatable {
    let header: SubtensorSubnetPriceHeaderViewModel
    let chart: SubtensorSubnetChartViewModel
    let periods: SubtensorSubnetPeriodsViewModel
}
