import SoraFoundation

extension StakingRewardFiltersPeriod {
    var title: LocalizableResource<String> {
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
                let startDate: Date?
                let endDate: Date
                switch customPeriod {
                case let .interval(start, end):
                    startDate = start
                    endDate = end
                case let .openEndDate(start):
                    startDate = start
                    endDate = Date()
                case let .openStartDate(end):
                    startDate = nil
                    endDate = end
                }

                guard let startDate = startDate else {
                    let formattedEndDate = DateFormatter.shortDate.value(for: locale).string(from: endDate) ?? ""
                    return R.string.localizable.stakingRewardFiltersPeriodCustomOpenShortDate(
                        formattedEndDate,
                        preferredLanguages: languages
                    )
                }

                guard let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day else {
                    return ""
                }

                return R.string.localizable.stakingRewardFiltersPeriodCustomMonthShort(
                    "\(days)",
                    preferredLanguages: languages
                )
            }
        }
    }
}
