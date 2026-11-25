import Foundation
import Foundation_iOS
import Operation_iOS

final class TransactionTrackingFacade {
    let trackers: [ChainTransactionTracking]
    let resolver: TransactionHistoryResolving
    let chainRegistry: ChainRegistryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var entries: [TransactionTrackingKey: Entry] = [:]
    private var recentlyResolved: [TransactionTrackingKey: Date] = [:]
    private var isActivated = false

    init(
        trackers: [ChainTransactionTracking],
        resolver: TransactionHistoryResolving,
        chainRegistry: ChainRegistryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.trackers = trackers
        self.resolver = resolver
        self.chainRegistry = chainRegistry
        self.applicationHandler = applicationHandler
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - TransactionTrackingFacadeProtocol

extension TransactionTrackingFacade: TransactionTrackingFacadeProtocol {
    func activate() {
        mutex.lock()
        let isFirstActivation = !isActivated
        isActivated = true
        mutex.unlock()

        guard isFirstActivation else {
            return
        }

        applicationHandler.delegate = self
    }

    @discardableResult
    func track(_ request: TransactionTrackingRequest) -> TransactionTrackingHandleProtocol {
        mutex.lock()
        let replacedWatch = register(request)
        mutex.unlock()

        replacedWatch?.stop()

        return TransactionTrackingHandle(key: request.key)
    }
}

// MARK: - Private

private extension TransactionTrackingFacade {
    struct Entry {
        var request: TransactionTrackingRequest
        var watch: TransactionWatching
        var watchId: UUID
        var isResolving: Bool
    }

    enum Constants {
        static let recentlyResolvedLimit = 256
        static let recentlyResolvedLifetime: TimeInterval = 30 * 60
    }

    func register(_ request: TransactionTrackingRequest) -> TransactionWatching? {
        let key = request.key

        pruneRecentlyResolved(now: Date())

        if let entry = entries[key] {
            guard case .fresh = request.mode, entry.request.mode.isRecovered, !entry.isResolving else {
                return nil
            }

            return replaceWatch(of: entry, with: request)
        }

        guard recentlyResolved[key] == nil else {
            logger.debug("Tracking: \(key) ignored, recently resolved")
            return nil
        }

        do {
            guard let entry = try makeEntry(for: request) else {
                logger.debug("Tracking: \(key) has no tracker")
                return nil
            }

            entries[key] = entry

            logger.debug("Tracking: \(request.mode) \(key) started")
        } catch {
            logger.warning("Tracking: \(key) start failed \(error)")
        }

        return nil
    }

    func replaceWatch(of entry: Entry, with request: TransactionTrackingRequest) -> TransactionWatching? {
        do {
            guard let newEntry = try makeEntry(for: request) else {
                return nil
            }

            entries[request.key] = newEntry

            logger.debug("Tracking: \(request.key) upgraded")

            return entry.watch
        } catch {
            logger.warning("Tracking: \(request.key) upgrade failed \(error)")
            return nil
        }
    }

    // Runs under the lock: trackers and watches never call back synchronously, every callback hops to a queue.
    func makeEntry(for request: TransactionTrackingRequest) throws -> Entry? {
        guard
            let chain = chainRegistry.getChain(for: request.key.chainId),
            let tracker = trackers.first(where: { $0.canTrack(chain: chain) }) else {
            return nil
        }

        let key = request.key
        let watchId = UUID()

        let watch = try tracker.startWatch(for: request, chain: chain) { [weak self] result in
            self?.handle(result, for: key, watchId: watchId)
        }

        return Entry(request: request, watch: watch, watchId: watchId, isResolving: false)
    }

    func handle(_ result: TransactionWatchResult, for key: TransactionTrackingKey, watchId: UUID) {
        mutex.lock()
        let acceptedWatch = accept(result, for: key, watchId: watchId)
        mutex.unlock()

        guard let acceptedWatch, case let .decided(outcome) = result else {
            return
        }

        acceptedWatch.stop()

        execute(
            wrapper: resolver.createResolutionWrapper(for: key, outcome: outcome),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            self?.completeResolution(for: key, outcome: outcome, result: result)
        }
    }

    func accept(
        _ result: TransactionWatchResult,
        for key: TransactionTrackingKey,
        watchId: UUID
    ) -> TransactionWatching? {
        guard var entry = entries[key], !entry.isResolving else {
            return nil
        }

        switch result {
        case .undecided:
            if entry.watchId == watchId {
                entries[key] = nil
                logger.debug("Tracking: \(key) ended undecided")
            }

            return nil
        case .decided:
            entry.isResolving = true
            entries[key] = entry

            return entry.watch
        }
    }

    func completeResolution(
        for key: TransactionTrackingKey,
        outcome: TransactionTrackingOutcome,
        result: Result<Void, Error>
    ) {
        mutex.lock()
        entries[key] = nil
        recentlyResolved[key] = Date()
        pruneRecentlyResolved(now: Date())
        mutex.unlock()

        switch result {
        case .success:
            eventCenter.notify(with: WalletTransactionListUpdated())
            logger.debug("Tracking: \(key) resolved \(outcome)")
        case let .failure(error):
            logger.error("Tracking: \(key) resolution failed \(error)")
        }
    }

    func pruneRecentlyResolved(now: Date) {
        recentlyResolved = recentlyResolved.filter {
            now.timeIntervalSince($0.value) < Constants.recentlyResolvedLifetime
        }

        let overflow = recentlyResolved.count - Constants.recentlyResolvedLimit

        guard overflow > 0 else {
            return
        }

        recentlyResolved
            .sorted { $0.value < $1.value }
            .prefix(overflow)
            .forEach { recentlyResolved[$0.key] = nil }
    }
}

// MARK: - ApplicationHandlerDelegate

extension TransactionTrackingFacade: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        mutex.lock()
        let watches = entries.values.filter { !$0.isResolving }.map(\.watch)
        mutex.unlock()

        watches.forEach { $0.checkNow() }
    }
}

// MARK: - Shared

extension TransactionTrackingFacade {
    static let shared: TransactionTrackingFacadeProtocol = {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let logger = Logger.shared

        let trackers: [ChainTransactionTracking] = [
            EvmTransactionTracker(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue,
                logger: logger
            )
        ]

        return TransactionTrackingFacade(
            trackers: trackers,
            resolver: TransactionHistoryResolver(storageFacade: SubstrateDataStorageFacade.shared),
            chainRegistry: chainRegistry,
            applicationHandler: ApplicationHandler(),
            eventCenter: EventCenter.shared,
            operationQueue: operationQueue,
            logger: logger
        )
    }()
}
