import Foundation
import Foundation_iOS

struct StakingRewardFiltersViewModel: Equatable {
    var period: Period
    var customPeriod: CustomPeriod = .defaultValue

    enum Period: Int, Hashable, CaseIterable {
        case allTime
        case lastWeek
        case lastMonth
        case lastThreeMonths
        case lastSixMonths
        case lastYear
        case custom

        var name: LocalizableResource<String> {
            LocalizableResource<String> { selectedLocale in
                let languages = selectedLocale.rLanguages
                let strings = R.string(preferredLanguages: languages).localizable.self

                switch self {
                case .allTime:
                    return strings.stakingRewardFiltersPeriodAllTime()
                case .lastWeek:
                    return strings.stakingRewardFiltersPeriodLastWeek()
                case .lastMonth:
                    return strings.stakingRewardFiltersPeriodLastMonth()
                case .lastThreeMonths:
                    return strings.stakingRewardFiltersPeriodLastThreeMonths()
                case .lastSixMonths:
                    return strings.stakingRewardFiltersPeriodLastSixMonths()
                case .lastYear:
                    return strings.stakingRewardFiltersPeriodLastYear()
                case .custom:
                    return strings.stakingRewardFiltersPeriodCustom()
                }
            }
        }
    }
}

extension StakingRewardFiltersViewModel {
    struct CustomPeriod: Hashable {
        let startDay: StartDay
        let endDay: EndDay

        static let defaultValue = CustomPeriod(
            startDay: .init(
                value: nil,
                collapsed: true
            ),
            endDay: .init(
                value: .alwaysToday,
                collapsed: true
            )
        )
    }

    struct StartDay: Hashable {
        let value: Date?
        let collapsed: Bool
    }

    struct EndDay: Hashable {
        let value: EndDayValue?
        let collapsed: Bool
    }

    enum EndDayValue: Hashable {
        case exact(Date?)
        case alwaysToday
    }
}
