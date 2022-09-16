import Foundation

extension TimeInterval {
    func localizedDaysHours(for locale: Locale) -> String {
        let days = daysFromSeconds
        let hours = (self - TimeInterval(days).secondsFromDays).hoursFromSeconds

        var components: [String] = []

        if days > 0 {
            let daysString = R.string.localizable.commonDaysFormat(
                format: days, preferredLanguages: locale.rLanguages
            )

            components.append(daysString)
        }

        if hours > 0 {
            let hoursString = R.string.localizable.commonHoursFormat(
                format: hours, preferredLanguages: locale.rLanguages
            )

            components.append(hoursString)
        }

        return components.joined(separator: " ")
    }
}

extension UInt {
    func localizedDaysPeriod(for locale: Locale) -> String {
        if self == 1 {
            return R.string.localizable.commonDaysEveryday(preferredLanguages: locale.rLanguages)
        } else {
            return R.string.localizable.commonEveryDaysFormat(
                format: Int(bitPattern: self),
                preferredLanguages: locale.rLanguages
            )
        }
    }
}
