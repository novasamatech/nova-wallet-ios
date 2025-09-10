import Foundation
import Foundation_iOS

extension StakingRewardFiltersPeriod {
    func title(calendar: Calendar) -> LocalizableResource<String> {
        .init { locale in
            let languages = locale.rLanguages
            switch self {
            case .allTime:
                return R.string(preferredLanguages: languages).localizable.stakingRewardFiltersPeriodAllTimeShort()
            case .lastWeek:
                return R.string(preferredLanguages: languages).localizable.stakingRewardFiltersPeriodLastWeekShort()
            case .lastMonth:
                return R.string(preferredLanguages: languages).localizable.stakingRewardFiltersPeriodLastMonthShort()
            case .lastThreeMonths:
                return R.string(preferredLanguages: languages).localizable.stakingRewardFiltersPeriodLastThreeMonthsShort()
            case .lastSixMonths:
                return R.string(preferredLanguages: languages).localizable.stakingRewardFiltersPeriodLastSixMonthsShort()
            case .lastYear:
                return R.string(preferredLanguages: languages).localizable.stakingRewardFiltersPeriodLastYearShort()
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
