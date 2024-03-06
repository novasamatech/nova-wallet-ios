import RobinHood
import SoraFoundation
import SoraKeystore
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

protocol PushNotificationsTopicServiceProtocol {
    func refreshTopicSubscription()

    func save(
        settings: PushNotification.TopicSettings,
        callbackQueue: DispatchQueue?,
        completion: @escaping (Error?) -> Void
    )

    func saveLocal(
        settings: PushNotification.TopicSettings,
        callbackQueue: DispatchQueue?,
        completion: @escaping (Error?) -> Void
    )
}

final class PushNotificationsTopicService: PushNotificationsTopicServiceProtocol {
    let logger: LoggerProtocol
    let repository: AnyDataProviderRepository<PushNotification.TopicSettings>
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    init(
        repository: AnyDataProviderRepository<PushNotification.TopicSettings>,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global(),
        logger: LoggerProtocol
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
        self.workQueue = workQueue
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

    func refreshTopicSubscription() {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            dispatchInQueueWhenPossible(self?.workQueue) {
                do {
                    let topics = try operation.extractNoCancellableResultData().first?.topics ?? []

                    for topic in topics {
                        self?.subscribe(channel: topic.remoteId)
                    }

                } catch {
                    self?.logger.error("Refresh failed: \(error)")
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    func save(
        settings: PushNotification.TopicSettings,
        callbackQueue: DispatchQueue?,
        completion: @escaping (Error?) -> Void
    ) {
        let oldSettingsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let saveSettingsOperation = repository.replaceOperation {
            [settings]
        }

        saveSettingsOperation.addDependency(oldSettingsOperation)

        saveSettingsOperation.completionBlock = { [weak self] in
            dispatchInQueueWhenPossible(self?.workQueue) {
                do {
                    let oldSettings = try oldSettingsOperation.extractNoCancellableResultData().first
                    try saveSettingsOperation.extractNoCancellableResultData()

                    let oldTopics = oldSettings?.topics ?? []

                    for topic in oldTopics {
                        self?.unsubscribe(channel: topic.remoteId)
                    }

                    for topic in settings.topics {
                        self?.subscribe(channel: topic.remoteId)
                    }

                    dispatchInQueueWhenPossible(callbackQueue) {
                        completion(nil)
                    }

                } catch {
                    self?.logger.error("Refresh failed: \(error)")

                    dispatchInQueueWhenPossible(callbackQueue) {
                        completion(error)
                    }
                }
            }
        }

        operationQueue.addOperations([oldSettingsOperation, saveSettingsOperation], waitUntilFinished: false)
    }

    func saveLocal(
        settings: PushNotification.TopicSettings,
        callbackQueue: DispatchQueue?,
        completion: @escaping (Error?) -> Void
    ) {
        let operation = repository.replaceOperation {
            [settings]
        }

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: callbackQueue
        ) { result in
            switch result {
            case .success:
                completion(nil)
            case let .failure(error):
                completion(error)
            }
        }
    }
}
