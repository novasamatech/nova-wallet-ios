import RobinHood
import SoraFoundation
import SoraKeystore
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

protocol TopicServiceProtocol {
    func subscribe(to topic: PushNotification.Topic)
    func unsubscribe(from topic: PushNotification.Topic)

    func save(
        settings: PushNotification.TopicSettings,
        workingQueue: OperationQueue,
        callbackQueue: DispatchQueue?,
        completion: @escaping () -> Void
    )
}

final class TopicService: TopicServiceProtocol {
    let logger: LoggerProtocol
    let repository: AnyDataProviderRepository<PushNotification.TopicSettings>

    init(
        repository: AnyDataProviderRepository<PushNotification.TopicSettings>,
        logger: LoggerProtocol
    ) {
        self.repository = repository
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

    func subscribe(to topic: PushNotification.Topic) {
        subscribe(channel: topic.identifier)
    }

    func unsubscribe(from topic: PushNotification.Topic) {
        unsubscribe(channel: topic.identifier)
    }

    func save(
        settings: PushNotification.TopicSettings,
        workingQueue: OperationQueue,
        callbackQueue: DispatchQueue?,
        completion: @escaping () -> Void
    ) {
        let operation = repository.replaceOperation {
            [settings]
        }

        execute(
            operation: operation,
            inOperationQueue: workingQueue,
            runningCallbackIn: callbackQueue
        ) { _ in
            completion()
        }
    }
}
