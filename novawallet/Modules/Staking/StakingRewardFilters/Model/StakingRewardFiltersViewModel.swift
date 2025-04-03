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
                let strings = R.string.localizable.self
                let languages = selectedLocale.rLanguages

                switch self {
                case .allTime:
                    return strings.stakingRewardFiltersPeriodAllTime(preferredLanguages: languages)
                case .lastWeek:
                    return strings.stakingRewardFiltersPeriodLastWeek(preferredLanguages: languages)
                case .lastMonth:
                    return strings.stakingRewardFiltersPeriodLastMonth(preferredLanguages: languages)
                case .lastThreeMonths:
                    return strings.stakingRewardFiltersPeriodLastThreeMonths(preferredLanguages: languages)
                case .lastSixMonths:
                    return strings.stakingRewardFiltersPeriodLastSixMonths(preferredLanguages: languages)
                case .lastYear:
                    return strings.stakingRewardFiltersPeriodLastYear(preferredLanguages: languages)
                case .custom:
                    return strings.stakingRewardFiltersPeriodCustom(preferredLanguages: languages)
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
