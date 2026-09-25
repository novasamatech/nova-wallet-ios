import Foundation
import Operation_iOS

final class SubtensorEarnConfigProvider: BaseFetchOperationFactory {
    typealias Delivery = (Result<SubtensorEarnConfig, Error>) -> Void

    struct CacheEntry {
        let config: SubtensorEarnConfig
        let fetchedAt: TimeInterval
    }

    struct FailureEntry {
        let error: Error
        let failedAt: TimeInterval
    }

    static let cacheLifetime: TimeInterval = 30 * 60
    static let failureRetryInterval: TimeInterval = 5 * 60

    private let configURL: URL
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let timeProvider: () -> TimeInterval
    private let mutex = NSLock()

    private var cacheEntry: CacheEntry?
    private var failureEntry: FailureEntry?
    private var pendingDeliveries: [UUID: Delivery] = [:]
    private var isFetching = false
    private var loggedInvalidEntries: Set<String> = []

    #if DEBUG
        private let isFixtureMode = BittensorApiFixtureMode.isEnabled
    #endif

    init(
        configURL: URL,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now
    ) {
        self.configURL = configURL
        self.operationQueue = operationQueue
        self.logger = logger
        self.timeProvider = timeProvider
    }
}

extension SubtensorEarnConfigProvider: SubtensorEarnConfigProviderProtocol {
    func createConfigWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig> {
        createConfigWrapper(holdsFailures: false)
    }

    func createBackgroundConfigWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig> {
        createConfigWrapper(holdsFailures: true)
    }
}

private extension SubtensorEarnConfigProvider {
    enum Constants {
        static let timeout: TimeInterval = 30
    }

    func createConfigWrapper(holdsFailures: Bool) -> CompoundOperationWrapper<SubtensorEarnConfig> {
        switch immediateDelivery(holdsFailures: holdsFailures) {
        case let .success(config):
            return .createWithResult(config)
        case let .failure(error):
            return .createWithError(error)
        case nil:
            break
        }

        let requestId = UUID()

        let operation = AsyncClosureOperation<SubtensorEarnConfig>(
            operationClosure: { [weak self] completion in
                guard let self else {
                    completion(.failure(BaseOperationError.parentOperationCancelled))

                    return
                }

                requestConfig(for: requestId, holdsFailures: holdsFailures, completion: completion)
            },
            cancelationClosure: { [weak self] in
                self?.cancelRequest(for: requestId)
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func isFresh(_ entry: CacheEntry) -> Bool {
        let age = timeProvider() - entry.fetchedAt

        return age >= 0 && age < Self.cacheLifetime
    }

    func isWithinRetryInterval(_ entry: FailureEntry) -> Bool {
        let age = timeProvider() - entry.failedAt

        return age >= 0 && age < Self.failureRetryInterval
    }

    func immediateDelivery(holdsFailures: Bool) -> Result<SubtensorEarnConfig, Error>? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return immediateDeliveryLocked(holdsFailures: holdsFailures)
    }

    func immediateDeliveryLocked(holdsFailures: Bool) -> Result<SubtensorEarnConfig, Error>? {
        if let cacheEntry, isFresh(cacheEntry) {
            return .success(cacheEntry.config)
        }

        guard holdsFailures, let failureEntry, isWithinRetryInterval(failureEntry) else {
            return nil
        }

        return cacheEntry.map { .success($0.config) } ?? .failure(failureEntry.error)
    }

    func requestConfig(for requestId: UUID, holdsFailures: Bool, completion: @escaping Delivery) {
        mutex.lock()

        if let immediate = immediateDeliveryLocked(holdsFailures: holdsFailures) {
            mutex.unlock()

            completion(immediate)

            return
        }

        pendingDeliveries[requestId] = completion

        let shouldStartFetch = !isFetching
        isFetching = true

        mutex.unlock()

        if shouldStartFetch {
            startFetch()
        }
    }

    func cancelRequest(for requestId: UUID) {
        mutex.lock()

        pendingDeliveries[requestId] = nil

        mutex.unlock()
    }

    func startFetch() {
        execute(
            wrapper: createFetchWrapper(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { result in
            self.completeFetch(with: result)
        }
    }

    func createFetchWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig> {
        #if DEBUG
            if isFixtureMode {
                let fixtureOperation = ClosureOperation<SubtensorEarnConfig> {
                    try JSONDecoder().decode(SubtensorEarnConfig.self, from: Data(Self.fixtureJSON.utf8))
                }

                return CompoundOperationWrapper(targetOperation: fixtureOperation)
            }
        #endif

        let fetchOperation: BaseOperation<SubtensorEarnConfig> = createFetchOperation(
            from: configURL,
            shouldUseCache: false,
            timeout: Constants.timeout
        )

        return CompoundOperationWrapper(targetOperation: fetchOperation)
    }

    func completeFetch(with result: Result<SubtensorEarnConfig, Error>) {
        mutex.lock()

        isFetching = false

        let deliveries = Array(pendingDeliveries.values)
        pendingDeliveries = [:]

        var newInvalidEntries: [String] = []
        let delivery: Result<SubtensorEarnConfig, Error>

        switch result {
        case let .success(config):
            cacheEntry = CacheEntry(config: config, fetchedAt: timeProvider())
            failureEntry = nil

            for entry in config.invalidEntries where loggedInvalidEntries.insert(entry).inserted {
                newInvalidEntries.append(entry)
            }

            delivery = .success(config)
        case let .failure(error):
            failureEntry = FailureEntry(error: error, failedAt: timeProvider())
            delivery = cacheEntry.map { .success($0.config) } ?? .failure(error)
        }

        mutex.unlock()

        newInvalidEntries.forEach { logger.warning("Subtensor Earn config entry ignored: \($0)") }

        if case let .failure(error) = result {
            logger.warning("Subtensor Earn config refresh failed: \(error)")
        }

        deliveries.forEach { $0(delivery) }
    }
}

#if DEBUG
    extension SubtensorEarnConfigProvider {
        static let fixtureJSON = """
        {
          "version": 1,
          "entry": { "enabled": true, "newBadgeUntil": "2026-12-31" },
          "headlineMaxAnnualRate": "0.40",
          "preferredRootValidator": "\(BittensorApiFixtureWorld.validator(.aster).hotkey)",
          "logoBaseUrl": "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/bittensor/",
          "subnets": {
            "64": {
              "registeredAt": 4531295,
              "preferredValidator": "\(BittensorApiFixtureWorld.validator(.ember).hotkey)",
              "coingeckoId": "chutes",
              "logo": "sn64-4531295.png"
            }
          }
        }
        """
    }
#endif
