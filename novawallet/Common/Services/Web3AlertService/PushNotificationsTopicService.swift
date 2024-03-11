import RobinHood
import SoraFoundation
import SoraKeystore
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
        AsyncClosureOperation(
            cancelationClosure: {},
            operationClosure: { [weak self] completionClosure in
                let messaging = Messaging.messaging()
                let (newTopics, removedTopics) = try topicChanges()

                self?.logger.debug("Subscribing: \(newTopics)")
                self?.logger.debug("Unsubscribing: \(removedTopics)")

                Task {
                    do {
                        try await withThrowingTaskGroup(of: Void.self) { group in
                            for newTopic in newTopics {
                                group.addTask {
                                    try await messaging.subscribe(toTopic: newTopic.remoteId)
                                }
                            }

                            for removedTopic in removedTopics {
                                group.addTask {
                                    try await messaging.unsubscribe(fromTopic: removedTopic.remoteId)
                                }
                            }

                            try await group.waitForAll()
                        }

                        completionClosure(.success(()))
                    } catch {
                        completionClosure(.failure(error))
                    }
                }
            }
        )
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
