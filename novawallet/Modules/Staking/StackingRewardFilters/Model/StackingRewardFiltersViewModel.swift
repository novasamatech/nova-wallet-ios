import SoraFoundation

struct StackingRewardFiltersViewModel {
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
                    return strings.stackingRewardFiltersPeriodAllTime(preferredLanguages: languages)
                case .lastWeek:
                    return strings.stackingRewardFiltersPeriodLastWeek(preferredLanguages: languages)
                case .lastMonth:
                    return strings.stackingRewardFiltersPeriodLastMonth(preferredLanguages: languages)
                case .lastThreeMonths:
                    return strings.stackingRewardFiltersPeriodLastThreeMonths(preferredLanguages: languages)
                case .lastSixMonths:
                    return strings.stackingRewardFiltersPeriodLastSixMonths(preferredLanguages: languages)
                case .lastYear:
                    return strings.stackingRewardFiltersPeriodLastYear(preferredLanguages: languages)
                case .custom:
                    return strings.stackingRewardFiltersPeriodCustom(preferredLanguages: languages)
                }
            }
        }
    }
}

extension StackingRewardFiltersViewModel {
    struct CustomPeriod: Hashable {
        let startDay: StartDay
        let endDay: EndDay

        static let defaultValue = CustomPeriod(
            startDay: .init(
                value: nil,
                isCollapsed: true
            ),
            endDay: .init(
                value: nil,
                collapsed: true
            )
        )
    }

    struct StartDay: Hashable {
        let value: Date?
        let isCollapsed: Bool
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
