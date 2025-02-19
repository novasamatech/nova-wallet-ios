import Foundation

struct PriceChartPeriodControlViewModel {
    let periods: [PriceChartPeriodViewModel]
}

enum PriceChartPeriodViewModel: Equatable {
    case day(String)
    case week(String)
    case month(String)
    case year(String)
    case allTime(String)

    var title: String {
        switch self {
        case let .day(title),
             let .week(title),
             let .month(title),
             let .year(title),
             let .allTime(title): title
        }
    }
}
