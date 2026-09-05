import Foundation

/// The repo's `.iso8601` encoding strategy drops milliseconds; Android sends
/// `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`, so analytics formats timestamps itself.
enum ISO8601MillisFormatter {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
