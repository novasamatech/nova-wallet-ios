import Foundation

enum StakingRewardFiltersPeriod: Hashable {
    case allTime
    case lastWeek
    case lastMonth
    case lastThreeMonths
    case lastSixMonths
    case lastYear
    case custom(start: Date?, end: Date?)
}
