import RobinHood
import SoraFoundation
import SoraKeystore
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

protocol TopicServiceProtocol {
    func subscribe(to topic: NotificationTopic)
    func unsubscribe(from topic: NotificationTopic)
}

final class TopicService: TopicServiceProtocol {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    private func subscribe(channel: String) {
        Messaging.messaging().subscribe(toTopic: channel) { [weak self] error in
            if let error = error {
                self?.logger.error(error.localizedDescription)
            }
        }
    }

    private func unsubscribe(channel: String) {
        Messaging.messaging().unsubscribe(fromTopic: channel) { [weak self] error in
            if let error = error {
                self?.logger.error(error.localizedDescription)
            }
        }
    }

    func subscribe(to topic: NotificationTopic) {
        subscribe(channel: topic.identifier)
    }

    func unsubscribe(from topic: NotificationTopic) {
        unsubscribe(channel: topic.identifier)
    }
}
