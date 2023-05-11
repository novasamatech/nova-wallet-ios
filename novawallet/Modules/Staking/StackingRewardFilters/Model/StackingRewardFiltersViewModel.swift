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
                switch self {
                case .allTime:
                    return R.string.localizable.stackingRewardFiltersPeriodAllTime(preferredLanguages: selectedLocale.rLanguages)
                case .lastWeek:
                    return R.string.localizable.stackingRewardFiltersPeriodLastWeek(preferredLanguages: selectedLocale.rLanguages)
                case .lastMonth:
                    return R.string.localizable.stackingRewardFiltersPeriodLastMonth(preferredLanguages: selectedLocale.rLanguages)
                case .lastThreeMonths:
                    return R.string.localizable.stackingRewardFiltersPeriodLastThreeMonths(preferredLanguages: selectedLocale.rLanguages)
                case .lastSixMonths:
                    return R.string.localizable.stackingRewardFiltersPeriodLastSixMonths(preferredLanguages: selectedLocale.rLanguages)
                case .lastYear:
                    return R.string.localizable.stackingRewardFiltersPeriodLastYear(preferredLanguages: selectedLocale.rLanguages)
                case .custom:
                    return R.string.localizable.stackingRewardFiltersPeriodCustom(preferredLanguages: selectedLocale.rLanguages)
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
                isCollapsed: true
            )
        )
    }

    struct StartDay: Hashable {
        let value: Date?
        let isCollapsed: Bool
    }

    struct EndDay: Hashable {
        let value: EndDayValue?
        let isCollapsed: Bool
    }

    enum EndDayValue: Hashable {
        case exact(Date?)
        case alwaysToday
    }
}
