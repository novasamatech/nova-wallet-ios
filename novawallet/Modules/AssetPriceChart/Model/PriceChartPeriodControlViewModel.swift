import Foundation

struct PriceChartPeriodControlViewModel {
    let periods: [PriceChartPeriodViewModel]
    let selectedPeriodIndex: Int
}

struct PriceChartPeriodViewModel: Equatable {
    let period: PriceChartPeriod
    let text: String
}

enum PriceChartPeriod: Equatable {
    case day
    case week
    case month
    case year
    case allTime
}
