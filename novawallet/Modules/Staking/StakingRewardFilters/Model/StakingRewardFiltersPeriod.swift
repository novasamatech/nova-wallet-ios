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
    init(rawValue: String, startDate: Date?, endDate: Date?) {
        switch rawValue {
        case StakingRewardFiltersPeriod.allTime.stringValue:
            self = .allTime
        case StakingRewardFiltersPeriod.lastWeek.stringValue:
            self = .lastWeek
        case StakingRewardFiltersPeriod.lastMonth.stringValue:
            self = .lastMonth
        case StakingRewardFiltersPeriod.lastThreeMonths.stringValue:
            self = .lastThreeMonths
        case StakingRewardFiltersPeriod.lastSixMonths.stringValue:
            self = .lastSixMonths
        case StakingRewardFiltersPeriod.lastYear.stringValue:
            self = .lastYear
        case Self.customIntervalRawValue:
            guard let startDate = startDate, let endDate = endDate else {
                self = .allTime
                return
            }
            self = .custom(.interval(startDate, endDate))
        case Self.customOpenEndDateRawValue:
            self = startDate.map { .custom(.openEndDate(startDate: $0)) } ?? .allTime
        default:
            self = .allTime
        }
    }

    var stringValue: String {
        switch self {
        case .allTime:
            return "allTime"
        case .lastWeek:
            return "lastWeek"
        case .lastMonth:
            return "lastMonth"
        case .lastThreeMonths:
            return "lastThreeMonths"
        case .lastSixMonths:
            return "lastSixMonths"
        case .lastYear:
            return "lastYear"
        case let .custom(customPeriod):
            switch customPeriod {
            case .interval:
                return Self.customIntervalRawValue
            case .openEndDate:
                return Self.customOpenEndDateRawValue
            }
        }
    }

    static let customIntervalRawValue = "interval"
    static let customOpenEndDateRawValue = "openEndDate"

    var startDate: Date? {
        switch self {
        case .allTime, .lastWeek, .lastMonth, .lastThreeMonths, .lastSixMonths, .lastYear:
            return nil
        case let .custom(customPeriod):
            switch customPeriod {
            case let .interval(startDate, _):
                return startDate
            case let .openEndDate(startDate):
                return startDate
            }
        }
    }

    var endDate: Date? {
        switch self {
        case .allTime, .lastWeek, .lastMonth, .lastThreeMonths, .lastSixMonths, .lastYear:
            return nil
        case let .custom(customPeriod):
            switch customPeriod {
            case let .interval(_, endDate):
                return endDate
            case .openEndDate:
                return nil
            }
        }
    }
}

typealias StakingRewardFiltersInterval = (startTimestamp: Int64?, endTimestamp: Int64?)

extension StakingRewardFiltersPeriod {
    var interval: StakingRewardFiltersInterval {
        let calendar = Calendar.current
        let endToday = calendar.dateInterval(of: .day, for: Date())?.end ?? Date()

        switch self {
        case .allTime:
            return (startTimestamp: nil, endTimestamp: nil)
        case .lastWeek:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: endToday)?.timeIntervalSince1970
            return (startTimestamp: sevenDaysAgo.map { Int64($0) }, endTimestamp: nil)
        case .lastMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: endToday)?.timeIntervalSince1970
            return (startTimestamp: monthAgo.map { Int64($0) }, endTimestamp: nil)
        case .lastThreeMonths:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: endToday)?.timeIntervalSince1970
            return (startTimestamp: threeMonthsAgo.map { Int64($0) }, endTimestamp: nil)
        case .lastSixMonths:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: endToday)?.timeIntervalSince1970
            return (startTimestamp: sixMonthsAgo.map { Int64($0) }, endTimestamp: nil)
        case .lastYear:
            let twelveMonthsAgo = calendar.date(byAdding: .year, value: -1, to: endToday)?.timeIntervalSince1970
            return (startTimestamp: twelveMonthsAgo.map { Int64($0) }, endTimestamp: nil)
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
