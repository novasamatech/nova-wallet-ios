import Foundation
import Operation_iOS

final class SubtensorEarnConfigProvider: BaseFetchOperationFactory {
    typealias Delivery = (Result<SubtensorEarnConfig, Error>) -> Void

    enum RequestKind {
        case interactive
        case background
    }

    struct CacheEntry {
        let config: SubtensorEarnConfig
        let fetchedAt: TimeInterval
    }

    struct FailureEntry {
        let error: Error
        let failedAt: TimeInterval
    }

    struct PendingDelivery {
        let kind: RequestKind
        let completion: Delivery
    }

    static let cacheLifetime: TimeInterval = 30 * 60
    static let failureRetryInterval: TimeInterval = 5 * 60

    private let configURL: URL
    private let bundledConfig: SubtensorEarnConfig?
    private let entryStore: SubtensorEarnConfigEntryStoring
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let timeProvider: () -> TimeInterval
    private let mutex = NSLock()

    private var cacheEntry: CacheEntry?
    private var failureEntry: FailureEntry?
    private var pendingDeliveries: [UUID: PendingDelivery] = [:]
    private var isFetching = false
    private var loggedInvalidEntries: Set<String> = []

    #if DEBUG
        private let isFixtureMode = BittensorApiFixtureMode.isEnabled
    #endif

    init(
        configURL: URL,
        bundledConfig: SubtensorEarnConfig?,
        entryStore: SubtensorEarnConfigEntryStoring,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now
    ) {
        self.configURL = configURL
        self.bundledConfig = bundledConfig
        self.entryStore = entryStore
        self.operationQueue = operationQueue
        self.logger = logger
        self.timeProvider = timeProvider

        bundledConfig?.invalidEntries.forEach { logger.warning("Subtensor bundled Earn config entry ignored: \($0)") }
    }
}

extension SubtensorEarnConfigProvider: SubtensorEarnConfigProviderProtocol {
    func createConfigWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig> {
        createConfigWrapper(for: .interactive)
    }

    func createBackgroundConfigWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig> {
        createConfigWrapper(for: .background)
    }
}

private extension SubtensorEarnConfigProvider {
    enum Constants {
        static let timeout: TimeInterval = 30
    }

    func createConfigWrapper(for kind: RequestKind) -> CompoundOperationWrapper<SubtensorEarnConfig> {
        #if DEBUG
            if isFixtureMode {
                return createFixtureWrapper()
            }
        #endif

        switch immediateDelivery(for: kind) {
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

                requestConfig(for: requestId, kind: kind, completion: completion)
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

    func immediateDelivery(for kind: RequestKind) -> Result<SubtensorEarnConfig, Error>? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return immediateDeliveryLocked(for: kind)
    }

    func immediateDeliveryLocked(for kind: RequestKind) -> Result<SubtensorEarnConfig, Error>? {
        if let cacheEntry, isFresh(cacheEntry) {
            return .success(cacheEntry.config)
        }

        guard kind == .background, let failureEntry, isWithinRetryInterval(failureEntry) else {
            return nil
        }

        return backgroundFallbackLocked(for: failureEntry.error)
    }

    func requestConfig(for requestId: UUID, kind: RequestKind, completion: @escaping Delivery) {
        mutex.lock()

        if let immediate = immediateDeliveryLocked(for: kind) {
            mutex.unlock()

            completion(immediate)

            return
        }

        pendingDeliveries[requestId] = PendingDelivery(kind: kind, completion: completion)

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

        let newInvalidEntries = recordLocked(result)

        var resolvedResults: [RequestKind: Result<SubtensorEarnConfig, Error>] = [:]

        let completions = deliveries.map { delivery -> (Delivery, Result<SubtensorEarnConfig, Error>) in
            let resolved = resolvedResults[delivery.kind] ?? resolveLocked(result, for: delivery.kind)
            resolvedResults[delivery.kind] = resolved

            return (delivery.completion, resolved)
        }

        mutex.unlock()

        newInvalidEntries.forEach { logger.warning("Subtensor Earn config entry ignored: \($0)") }

        if case let .failure(error) = result {
            logger.warning("Subtensor Earn config refresh failed: \(error)")
        }

        completions.forEach { completion, resolved in
            completion(resolved)
        }
    }

    func recordLocked(_ result: Result<SubtensorEarnConfig, Error>) -> [String] {
        switch result {
        case let .success(config):
            cacheEntry = CacheEntry(config: config, fetchedAt: timeProvider())
            failureEntry = nil

            entryStore.saveRemoteEntry(SubtensorEarnConfigRemoteEntry(entry: config.entry))

            var newInvalidEntries: [String] = []

            for entry in config.invalidEntries where loggedInvalidEntries.insert(entry).inserted {
                newInvalidEntries.append(entry)
            }

            return newInvalidEntries
        case let .failure(error):
            failureEntry = FailureEntry(error: error, failedAt: timeProvider())

            if Self.isNotFound(error) {
                entryStore.saveRemoteEntry(nil)
            }

            return []
        }
    }

    func resolveLocked(
        _ result: Result<SubtensorEarnConfig, Error>,
        for kind: RequestKind
    ) -> Result<SubtensorEarnConfig, Error> {
        guard case let .failure(error) = result else {
            return result
        }

        switch kind {
        case .interactive:
            return interactiveFallbackLocked(for: error)
        case .background:
            return backgroundFallbackLocked(for: error)
        }
    }

    func backgroundFallbackLocked(for error: Error) -> Result<SubtensorEarnConfig, Error> {
        cacheEntry.map { .success($0.config) } ?? .failure(error)
    }

    func interactiveFallbackLocked(for error: Error) -> Result<SubtensorEarnConfig, Error> {
        if Self.isNotFound(error) {
            return bundledConfig.map { .success($0) } ?? .failure(error)
        }

        if let cacheEntry {
            return .success(cacheEntry.config)
        }

        guard let bundledConfig else {
            return .failure(error)
        }

        guard let storedEntry = entryStore.loadRemoteEntry() else {
            return .success(bundledConfig)
        }

        return .success(bundledConfig.replacingEntry(storedEntry.entry))
    }

    static func isNotFound(_ error: Error) -> Bool {
        (error as? NetworkResponseError) == .resourceNotFound
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

        private func createFixtureWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig> {
            let fixtureOperation = ClosureOperation<SubtensorEarnConfig> {
                try JSONDecoder().decode(SubtensorEarnConfig.self, from: Data(Self.fixtureJSON.utf8))
            }

            return CompoundOperationWrapper(targetOperation: fixtureOperation)
        }
    }
#endif
