import Foundation
import SoraFoundation

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

    func localizedDaysHoursIncludingZero(for locale: Locale) -> String {
        let days = daysFromSeconds
        let hours = (self - TimeInterval(days).secondsFromDays).hoursFromSeconds

        guard days > 0 || hours > 0 else {
            return R.string.localizable.commonDaysFormat(format: 0, preferredLanguages: locale.rLanguages)
        }

        return localizedDaysHours(for: locale)
    }

    func localizedFractionDays(for locale: Locale, shouldAnnotate: Bool) -> String {
        let days = fractionDaysFromSeconds
        let formatter = NumberFormatter.decimalFormatter(precision: 1, rounding: .down)
        let optDaysString = formatter.stringFromDecimal(days)

        if shouldAnnotate {
            if let daysString = optDaysString {
                return R.string.localizable.commonDaysFractionFormat(
                    daysString,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return ""
            }
        } else {
            return optDaysString ?? ""
        }
    }

    func localizedDaysOrTime(for locale: Locale) -> String? {
        let days = daysFromSeconds

        if days > 0 {
            let daysString = R.string.localizable.commonDaysFormat(
                format: days, preferredLanguages: locale.rLanguages
            )
            return daysString
        } else {
            let formatter = DateComponentsFormatter.fullTime
            return formatter.value(for: locale).string(from: self)
        }
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
