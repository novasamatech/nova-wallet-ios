import Foundation

struct PriceAPI {
    static let baseURL = URL(string: "https://api.coingecko.com/api/v3")!
    static let proxyBaseURL = URL(string: "https://tokens-price.novasama-tech.org/api/v3")!
    static let price = "simple/price"

    static func priceHistory(for tokenId: String) -> String {
        "coins/\(tokenId)/market_chart"
    }
}

extension PriceAPI {
    enum Period: String {
        case day = "1"
        case week = "7"
        case month = "30"
        case year = "365"
        case allTime = "max"

        init(from period: PriceHistoryPeriod) {
            switch period {
            case .day: self = .day
            case .week: self = .week
            case .month: self = .month
            case .year: self = .year
            case .allTime: self = .allTime
            }
        }
    }
}

enum PriceHistoryPeriod {
    case day
    case week
    case month
    case year
    case allTime

    var startedAt: UInt64? {
        let calendar = Calendar.current
        let endToday = calendar.dateInterval(of: .day, for: Date())?.end ?? Date()

        var interval: TimeInterval?

        switch self {
        case .allTime:
            interval = nil
        case .week:
            interval = calendar.date(byAdding: .day, value: -7, to: endToday)?.timeIntervalSince1970
        case .month:
            interval = calendar.date(byAdding: .month, value: -1, to: endToday)?.timeIntervalSince1970
        case .year:
            interval = calendar.date(byAdding: .year, value: -1, to: endToday)?.timeIntervalSince1970
        case .day:
            interval = calendar.date(byAdding: .day, value: -1, to: endToday)?.timeIntervalSince1970
        }

        return interval.map { UInt64($0) }
    }
}
