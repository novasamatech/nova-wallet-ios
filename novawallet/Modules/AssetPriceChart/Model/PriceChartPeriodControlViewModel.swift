import Foundation

struct PriceChartPeriodControlViewModel {
    let periods: [PriceChartPeriodViewModel]
    let selectedPeriodIndex: Int
}

struct PriceChartPeriodViewModel: Equatable {
    let period: PriceHistoryPeriod
    let text: String
}
