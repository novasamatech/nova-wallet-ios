import Foundation

struct NotificationContentResult {
    let title: String
    let subtitle: String
}

extension NotificationContentResult {
    static func createUnsupportedResult(for locale: Locale) -> NotificationContentResult {
        .init(
            title: R.string.localizable.pushNotificationDefaultTitle(preferredLanguages: locale.rLanguages),
            subtitle: R.string.localizable.pushNotificationUnsupportedBody(preferredLanguages: locale.rLanguages)
        )
    }
}
