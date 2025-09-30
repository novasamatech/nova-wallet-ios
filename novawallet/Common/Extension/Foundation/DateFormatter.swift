import Foundation
import Foundation_iOS

extension DateFormatter {
    static var txHistory: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "HHmm", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var txDetails: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMMyyyyHHmmss", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var fullDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "MMMM d, yyyy", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var shortDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMMyyyy", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var shortDateHoursMinutes: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMMyyyyHHmm", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var shortDateAndTime: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMMyyyyHHmmss", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var txHistoryDate: DateFormatter {
        let dateFormatterBuilder = CompoundDateFormatterBuilder()

        let today = LocalizableResource { locale in
            R.string.localizable.commonToday(preferredLanguages: locale.rLanguages)
        }
        let yesterday = LocalizableResource { locale in
            R.string.localizable.commonYesterday(preferredLanguages: locale.rLanguages)
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM"

        return dateFormatterBuilder
            .withToday(title: today)
            .withYesterday(title: yesterday)
            .withThisYear(dateFormatter: dateFormatter.localizableResource())
            .build(defaultFormat: "dd MMMM yyyy")
    }

    static var chartEntryDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(
                fromTemplate: "d MMM' at 'HH:mm",
                options: 0,
                locale: locale
            )
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var chartEntryWithYear: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(
                fromTemplate: "d MMM' at 'HH:mm, yyyy",
                options: 0,
                locale: locale
            )
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }
}

extension DateComponentsFormatter {
    static var fullTime: LocalizableResource<DateComponentsFormatter> {
        LocalizableResource { locale in
            var calendar = Calendar.current
            calendar.locale = locale
            let dateFormatter = DateComponentsFormatter()
            dateFormatter.allowedUnits = [.hour, .minute, .second]
            dateFormatter.unitsStyle = .positional
            dateFormatter.zeroFormattingBehavior = .pad
            dateFormatter.calendar = calendar

            return dateFormatter
        }
    }
}
