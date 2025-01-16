import Operation_iOS
import Foundation_iOS
import Keystore_iOS
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

protocol PushNotificationsTopicServiceProtocol {
    func save(
        settings: PushNotification.TopicSettings,
        callbackQueue: DispatchQueue?,
        completion: @escaping (Error?) -> Void
    )

    func saveDiff(
        settings: PushNotification.TopicSettings,
        callbackQueue: DispatchQueue?,
        completion: @escaping (Error?) -> Void
    )
}

final class PushNotificationsTopicService {
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

    private func saveSubscriptions(
        from topicChanges: @escaping () throws -> (Set<PushNotification.Topic>, Set<PushNotification.Topic>)
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            let messaging = Messaging.messaging()
            let (newTopics, removedTopics) = try topicChanges()

            self?.logger.debug("Subscribing: \(newTopics)")
            self?.logger.debug("Unsubscribing: \(removedTopics)")

            for newTopic in newTopics {
                messaging.subscribe(toTopic: newTopic.remoteId) { optError in
                    if let error = optError {
                        self?.logger.error("Topic subscription failed \(newTopic.remoteId) \(error)")
                    } else {
                        self?.logger.debug("Topic subscribed: \(newTopic.remoteId)")
                    }
                }
            }

            for removedTopic in removedTopics {
                messaging.unsubscribe(fromTopic: removedTopic.remoteId) { optError in
                    if let error = optError {
                        self?.logger.error("Topic unsubscription failed \(error)")
                    } else {
                        self?.logger.debug("Topic unsubscribed: \(removedTopic.remoteId)")
                    }
                }
            }
        }
    }
}

extension PushNotificationsTopicService: PushNotificationsTopicServiceProtocol {
    func save(
        settings: PushNotification.TopicSettings,
        callbackQueue: DispatchQueue?,
        completion: @escaping (Error?) -> Void
    ) {
        let remoteSaveOperation = saveSubscriptions { (settings.topics, []) }

        let localSaveOperation = repository.replaceOperation {
            [settings]
        }

        localSaveOperation.configurationBlock = {
            do {
                try remoteSaveOperation.extractNoCancellableResultData()
            } catch {
                localSaveOperation.result = .failure(error)
            }
        }

        localSaveOperation.addDependency(remoteSaveOperation)

        localSaveOperation.completionBlock = { [weak self] in
            dispatchInQueueWhenPossible(callbackQueue) {
                do {
                    try localSaveOperation.extractNoCancellableResultData()

                    self?.logger.debug("Topics saved")

                    completion(nil)
                } catch {
                    self?.logger.error("Topics error failed \(error)")

                    completion(error)
                }
            }
        }

        operationQueue.addOperations(
            [remoteSaveOperation, localSaveOperation],
            waitUntilFinished: false
        )
    }

    func saveDiff(
        settings: PushNotification.TopicSettings,
        callbackQueue: DispatchQueue?,
        completion: @escaping (Error?) -> Void
    ) {
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let remoteSaveOperation = saveSubscriptions {
            let localTopics = try localFetchOperation.extractNoCancellableResultData().first?.topics ?? []
            let newTopics = settings.topics.subtracting(localTopics)
            let removedTopics = localTopics.subtracting(settings.topics)

            return (newTopics, removedTopics)
        }

        remoteSaveOperation.addDependency(localFetchOperation)

        let localSaveOperation = repository.replaceOperation {
            [settings]
        }

        localSaveOperation.configurationBlock = {
            do {
                try remoteSaveOperation.extractNoCancellableResultData()
            } catch {
                localSaveOperation.result = .failure(error)
            }
        }

        localSaveOperation.addDependency(remoteSaveOperation)

        localSaveOperation.completionBlock = { [weak self] in
            dispatchInQueueWhenPossible(callbackQueue) {
                do {
                    try localSaveOperation.extractNoCancellableResultData()

                    self?.logger.debug("Topics diff saved")

                    completion(nil)

                } catch {
                    self?.logger.error("Topics diff failed: \(error)")

                    completion(error)
                }
            }
        }

        operationQueue.addOperations(
            [localFetchOperation, localSaveOperation, remoteSaveOperation],
            waitUntilFinished: false
        )
    }
}
