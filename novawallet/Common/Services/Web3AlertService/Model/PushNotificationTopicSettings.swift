import RobinHood

extension PushNotification {
    struct TopicSettings: Codable, Equatable, Identifiable {
        var identifier: String { Self.getIdentifier() }
        let topics: [PushNotification.Topic]

        init(
            topics: [PushNotification.Topic]
        ) {
            self.topics = topics
        }

        static func getIdentifier() -> String {
            "LocalNotificationTopicSettingsIdentifier"
        }
    }
}

extension PushNotification.TopicSettings {
    func byTogglingAnnouncements() -> PushNotification.TopicSettings {
        let hasAppCustom = topics.contains { $0 == .appCustom }

        var newTopics = topics

        if hasAppCustom {
            newTopics.removeAll { $0 == .appCustom }
        } else {
            newTopics.append(.appCustom)
        }

        return .init(topics: topics)
    }
}
