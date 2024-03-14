import UserNotifications

extension NotificationContentResult {
    func toUserNotificationContent(with userInfo: [AnyHashable: Any] = [:]) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = ""
        content.body = subtitle
        content.userInfo = userInfo
        return content
    }
}
