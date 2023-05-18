import Foundation

enum StakingRewardFiltersPeriod: Hashable, Codable {
    case allTime
    case lastWeek
    case lastMonth
    case lastThreeMonths
    case lastSixMonths
    case lastYear
    case custom(start: Date?, end: Date?)
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
        case let .custom(start, end):
            return (
                startTimestamp: start.map { Int64($0.timeIntervalSince1970) },
                endTimestamp: end.map { Int64($0.timeIntervalSince1970) }
            )
        }
    }
}
