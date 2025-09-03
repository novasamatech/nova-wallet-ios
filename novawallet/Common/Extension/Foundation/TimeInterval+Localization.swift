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
            let daysString = R.string(preferredLanguages: locale.rLanguages).localizable.commonDaysFormat(
                format: days
            )

            components.append(daysString)
        }

        if hours > 0 {
            let hoursString = R.string(preferredLanguages: locale.rLanguages).localizable.commonHoursFormat(
                format: hours
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
            let daysString = R.string(preferredLanguages: locale.rLanguages).localizable.commonDaysFormat(
                format: days
            )

            components.append(daysString)
        }

        if hours > 0 {
            let hoursString = R.string(preferredLanguages: locale.rLanguages).localizable.commonHoursFormat(
                format: hours
            )

            components.append(hoursString)
        }

        if minutes > 0, components.count < 2 {
            let minutesString = R.string(preferredLanguages: locale.rLanguages).localizable.commonMinutesFormat(
                format: minutes
            )

            components.append(minutesString)
        }

        if components.isEmpty, let minutes = atLeastMinutesToShow {
            let minutesString = R.string(preferredLanguages: locale.rLanguages).localizable.commonMinutesFormat(
                format: minutes
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
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonDaysFormat(format: 0)
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
                return R.string(preferredLanguages: locale.rLanguages).localizable.commonDaysFractionFormat(
                    daysString
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
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonDaysEveryday()
        } else {
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonEveryDaysFormat(
                format: Int(bitPattern: self)
            )
        }
    }
}
