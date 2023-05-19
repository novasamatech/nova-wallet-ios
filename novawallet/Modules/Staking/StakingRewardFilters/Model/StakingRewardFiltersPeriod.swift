import Foundation

enum StakingRewardFiltersPeriod: Hashable, Codable {
    case allTime
    case lastWeek
    case lastMonth
    case lastThreeMonths
    case lastSixMonths
    case lastYear
    case custom(RewardFiltersCustomPeriod)

    enum RewardFiltersCustomPeriod: Hashable, Codable {
        case interval(Date, Date)
        case openEndDate(startDate: Date)
    }
}

extension StakingRewardFiltersPeriod {
    var interval: (startTimestamp: Int64?, endTimestamp: Int64?) {
        switch self {
        case .allTime:
            return (startTimestamp: nil, endTimestamp: nil)
        case .lastWeek:
            let sevenDaysAgo = Date().addingTimeInterval(-(.secondsInDay * 7)).timeIntervalSince1970
            return (startTimestamp: Int64(sevenDaysAgo), endTimestamp: nil)
        case .lastMonth:
            let monthAgo = Date().addingTimeInterval(-(.secondsInDay * 7 * 4)).timeIntervalSince1970
            return (startTimestamp: Int64(monthAgo), endTimestamp: nil)
        case .lastThreeMonths:
            let threeMonthsAgo = Date().addingTimeInterval(-(.secondsInDay * 7 * 4 * 3)).timeIntervalSince1970
            return (startTimestamp: Int64(threeMonthsAgo), endTimestamp: nil)
        case .lastSixMonths:
            let sixMonthsAgo = Date().addingTimeInterval(-(.secondsInDay * 7 * 4 * 6)).timeIntervalSince1970
            return (startTimestamp: Int64(sixMonthsAgo), endTimestamp: nil)
        case .lastYear:
            let twelveMonthsAgo = Date().addingTimeInterval(-(.secondsInDay * 7 * 4 * 12)).timeIntervalSince1970
            return (startTimestamp: Int64(twelveMonthsAgo), endTimestamp: nil)
        case let .custom(customPeriod):
            switch customPeriod {
            case let .interval(start, end):
                return (
                    startTimestamp: Int64(start.timeIntervalSince1970),
                    endTimestamp: Int64(end.timeIntervalSince1970)
                )
            case let .openEndDate(start):
                return (startTimestamp: Int64(start.timeIntervalSince1970), endTimestamp: nil)
            }
        }
    }
}
