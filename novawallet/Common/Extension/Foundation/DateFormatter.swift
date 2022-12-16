import Foundation
import SoraFoundation

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

    static var shortDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMMyyyy", options: 0, locale: locale)
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

    static var txHistoryDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let dateFormatterBuilder = CompoundDateFormatterBuilder()

            let today = LocalizableResource { _ in
                R.string.localizable.commonToday(preferredLanguages: locale.rLanguages)
            }
            let yesterday = LocalizableResource { _ in
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
