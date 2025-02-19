import Foundation

struct PriceChartPeriodControlViewModel {
    let periods: [PriceChartPeriodViewModel]
}

enum PriceChartPeriodViewModel {
    case day(String)
    case week(String)
    case month(String)
    case year(String)
    case allTime(String)
}
