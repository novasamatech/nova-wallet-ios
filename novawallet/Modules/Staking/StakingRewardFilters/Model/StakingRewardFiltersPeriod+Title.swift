import Foundation_iOS

extension StakingRewardFiltersPeriod {
    func title(calendar: Calendar) -> LocalizableResource<String> {
        .init { locale in
            let languages = locale.rLanguages
            switch self {
            case .allTime:
                return R.string.localizable.stakingRewardFiltersPeriodAllTimeShort(preferredLanguages: languages)
            case .lastWeek:
                return R.string.localizable.stakingRewardFiltersPeriodLastWeekShort(preferredLanguages: languages)
            case .lastMonth:
                return R.string.localizable.stakingRewardFiltersPeriodLastMonthShort(preferredLanguages: languages)
            case .lastThreeMonths:
                return R.string.localizable.stakingRewardFiltersPeriodLastThreeMonthsShort(
                    preferredLanguages: languages)
            case .lastSixMonths:
                return R.string.localizable.stakingRewardFiltersPeriodLastSixMonthsShort(preferredLanguages: languages)
            case .lastYear:
                return R.string.localizable.stakingRewardFiltersPeriodLastYearShort(preferredLanguages: languages)
            case let .custom(customPeriod):
                return customPeriodTitle(customPeriod, calendar: calendar, locale: locale)
            }
        }
    }

    private func customPeriodTitle(
        _ customPeriod: RewardFiltersCustomPeriod,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let startDate: Date
        let endDate: Date
        switch customPeriod {
        case let .interval(start, end):
            startDate = calendar.startOfDay(for: start)
            endDate = calendar.startOfDay(for: end)
        case let .openEndDate(start):
            startDate = calendar.startOfDay(for: start)
            endDate = calendar.startOfDay(for: Date())
        }

        guard let days = calendar.dateComponents([.day], from: startDate, to: endDate).day else {
            return ""
        }

        return R.string.localizable.stakingRewardFiltersPeriodCustomMonthShort(
            "\(days + 1)",
            preferredLanguages: locale.rLanguages
        )
    }
}
