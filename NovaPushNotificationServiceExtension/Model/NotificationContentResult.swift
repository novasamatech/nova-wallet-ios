import Foundation

struct NotificationContentResult {
    let title: String
    let subtitle: String?
    let body: String

    init(
        title: String,
        subtitle: String? = nil,
        body: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
    }
}

extension NotificationContentResult {
    static func createUnsupportedResult(for locale: Locale) -> NotificationContentResult {
        .init(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationDefaultTitle(),
            subtitle: nil,
            body: R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationUnsupportedBody()
        )
    }
}
