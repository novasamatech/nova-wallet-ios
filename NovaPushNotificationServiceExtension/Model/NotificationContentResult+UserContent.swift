import UserNotifications

extension NotificationContentResult {
    func toUserNotificationContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = ""
        content.body = subtitle

        return content
    }
}
