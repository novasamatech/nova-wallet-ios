import SoraFoundation

extension StakingRewardFiltersPeriod {
    func title(dateFormatter: LocalizableResource<DateFormatter>, calendar: Calendar) -> LocalizableResource<String> {
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
                return customPeriodTitle(customPeriod, dateFormatter: dateFormatter, calendar: calendar, locale: locale)
            }
        }
    }

    private func customPeriodTitle(
        _ customPeriod: RewardFiltersCustomPeriod,
        dateFormatter _: LocalizableResource<DateFormatter>,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let startDate: Date
        let endDate: Date
        switch customPeriod {
        case let .interval(start, end):
            startDate = start
            endDate = end
        case let .openEndDate(start):
            startDate = start
            endDate = Date()
        }

        guard let days = calendar.dateComponents([.day], from: startDate, to: endDate).day else {
            return ""
        }

        return R.string.localizable.stakingRewardFiltersPeriodCustomMonthShort(
            "\(days)",
            preferredLanguages: locale.rLanguages
        )
    }
}
