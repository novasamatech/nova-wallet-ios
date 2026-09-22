import Foundation

// RFC 9110 requires senders to use IMF-fixdate; obsolete forms are intentionally unsupported.
enum HTTPDateFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

    static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}
