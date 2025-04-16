import Foundation
import Foundation_iOS

extension TimeInterval {
    func localizedDaysHoursOrFallbackMinutes(
        for locale: Locale,
        preposition: String? = nil,
        separator: String = " ",
        shortcutHandler: PredefinedTimeShortcutProtocol? = nil,
        roundsDown: Bool = true
    ) -> String {
        let (days, hours) = getDaysAndHours(roundingDown: roundsDown)

        guard days > 0 || hours > 0 else {
            return localizedDaysHoursMinutes(
                for: locale,
                preposition: preposition ?? "",
                separator: separator,
                atLeastMinutesToShow: 1
            )
        }

        return localizedDaysHours(
            for: locale,
            preposition: preposition,
            separator: separator,
            shortcutHandler: shortcutHandler,
            roundsDown: roundsDown
        )
    }

    func localizedDaysHours(
        for locale: Locale,
        preposition: String? = nil,
        separator: String = " ",
        shortcutHandler: PredefinedTimeShortcutProtocol? = nil,
        roundsDown: Bool = true
    ) -> String {
        if
            let shortcut = shortcutHandler?.getShortcut(
                for: self,
                roundsDown: roundsDown,
                locale: locale
            ) {
            return shortcut
        }

        let (days, hours) = getDaysAndHours(roundingDown: roundsDown)

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

        let timeString = components.joined(separator: separator)

        if let preposition = preposition, !preposition.isEmpty {
            return preposition + " " + timeString
        } else {
            return timeString
        }
    }

    func localizedDaysHoursMinutes(
        for locale: Locale,
        preposition: String = "",
        separator: String = " ",
        atLeastMinutesToShow: Int? = nil
    ) -> String {
        let days = daysFromSeconds
        let hours = (self - TimeInterval(days).secondsFromDays).hoursFromSeconds
        let minutes = (self - TimeInterval(days).secondsFromDays -
            TimeInterval(hours).secondsFromHours).minutesFromSeconds

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

        if minutes > 0, components.count < 2 {
            let minutesString = R.string.localizable.commonMinutesFormat(
                format: minutes, preferredLanguages: locale.rLanguages
            )

            components.append(minutesString)
        }

        if components.isEmpty, let minutes = atLeastMinutesToShow {
            let minutesString = R.string.localizable.commonMinutesFormat(
                format: minutes, preferredLanguages: locale.rLanguages
            )

            components.append(minutesString)
        }

        let timeString = components.joined(separator: separator)

        if !preposition.isEmpty {
            return preposition + " " + timeString
        } else {
            return timeString
        }
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
        formatter.locale = locale
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

    func localizedDaysHoursOrTime(for locale: Locale) -> String? {
        let days = daysFromSeconds

        if days > 0 {
            return localizedDaysHours(for: locale)
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
