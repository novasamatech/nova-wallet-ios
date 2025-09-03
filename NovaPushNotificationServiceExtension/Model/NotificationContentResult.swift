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
