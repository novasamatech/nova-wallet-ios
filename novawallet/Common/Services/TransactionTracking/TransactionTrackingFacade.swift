import Foundation
import Foundation_iOS
import Operation_iOS

final class TransactionTrackingFacade {
    typealias Waiter = (TransactionTrackingResult) -> Void

    let trackers: [ChainTransactionTracking]
    let resolver: TransactionHistoryResolving
    let pickup: PendingTransactionPickupProtocol
    let chainRegistry: ChainRegistryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol
    let backgroundTimeKeeper: BackgroundTimeKeeping?

    private let mutex = NSLock()
    private var entries: [TransactionTrackingKey: Entry] = [:]
    private var recentlyResolved: [TransactionTrackingKey: RecentResolution] = [:]
    private var waiters: [TransactionTrackingKey: [UUID: Waiter]] = [:]
    private var isActivated = false

    init(
        trackers: [ChainTransactionTracking],
        resolver: TransactionHistoryResolving,
        pickup: PendingTransactionPickupProtocol,
        chainRegistry: ChainRegistryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        backgroundTimeKeeper: BackgroundTimeKeeping? = nil
    ) {
        self.trackers = trackers
        self.resolver = resolver
        self.pickup = pickup
        self.chainRegistry = chainRegistry
        self.applicationHandler = applicationHandler
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
        self.backgroundTimeKeeper = backgroundTimeKeeper
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
            runPickup()
            return
        }

        applicationHandler.delegate = self

        chainRegistry.chainsSubscribe(self, runningInQueue: .global(qos: .utility)) { [weak self] changes in
            guard changes.contains(where: { if case .insert = $0 { true } else { false } }) else {
                return
            }

            self?.runPickup()
        }
    }

    @discardableResult
    func track(_ request: TransactionTrackingRequest) -> TransactionTrackingHandleProtocol {
        mutex.lock()
        let replacedWatch = register(request)
        let backgroundUntil = entries[request.key]?.backgroundUntil
        mutex.unlock()

        replacedWatch?.stop()

        if let backgroundUntil {
            backgroundTimeKeeper?.keepAwakeIfInBackground(until: backgroundUntil)
        }

        return TransactionTrackingHandle(key: request.key)
    }

    func createResultWrapper(
        for key: TransactionTrackingKey,
        budget: TimeInterval
    ) -> CompoundOperationWrapper<TransactionTrackingResult> {
        let waiterId = UUID()

        let operation = AsyncClosureOperation<TransactionTrackingResult>(
            operationClosure: { [weak self] completion in
                guard let self else {
                    throw BaseOperationError.parentOperationCancelled
                }

                attachWaiter(waiterId, for: key, budget: budget) { completion(.success($0)) }
            },
            cancelationClosure: { [weak self] in
                _ = self?.takeWaiter(waiterId, for: key)
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

// MARK: - Private

private extension TransactionTrackingFacade {
    struct Entry {
        var request: TransactionTrackingRequest
        var watch: TransactionWatching
        var watchId: UUID
        var isResolving: Bool
        var backgroundUntil: Date?
    }

    struct RecentResolution {
        let resolvedAt: Date
        let outcome: TransactionTrackingOutcome
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

        var entry = Entry(request: request, watch: watch, watchId: watchId, isResolving: false)

        if backgroundTimeKeeper != nil, !request.mode.isRecovered {
            entry.backgroundUntil = Date().addingTimeInterval(tracker.backgroundWindow(for: chain))
        }

        return entry
    }

    func handle(_ result: TransactionWatchResult, for key: TransactionTrackingKey, watchId: UUID) {
        mutex.lock()
        let acceptedWatch = accept(result, for: key, watchId: watchId)
        mutex.unlock()

        releaseBackgroundTimeIfIdle()

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
        recentlyResolved[key] = RecentResolution(resolvedAt: Date(), outcome: outcome)
        pruneRecentlyResolved(now: Date())
        let keyWaiters = waiters.removeValue(forKey: key)
        mutex.unlock()

        releaseBackgroundTimeIfIdle()

        keyWaiters?.values.forEach { $0(.resolved(outcome)) }

        switch result {
        case .success:
            eventCenter.notify(with: WalletTransactionListUpdated())
            logger.debug("Tracking: \(key) resolved \(outcome)")
        case let .failure(error):
            logger.error("Tracking: \(key) resolution failed \(error)")
        }
    }

    func attachWaiter(
        _ waiterId: UUID,
        for key: TransactionTrackingKey,
        budget: TimeInterval,
        waiter: @escaping Waiter
    ) {
        mutex.lock()

        if let resolution = recentlyResolved[key] {
            mutex.unlock()
            waiter(.resolved(resolution.outcome))
            return
        }

        guard entries[key] != nil else {
            mutex.unlock()
            logger.warning("Tracking: \(key) not tracked, waiter still pending")
            waiter(.stillPending)
            return
        }

        waiters[key, default: [:]][waiterId] = waiter
        mutex.unlock()

        logger.debug("Tracking: \(key) waiter attached")

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + budget) { [weak self] in
            guard let waiter = self?.takeWaiter(waiterId, for: key) else {
                return
            }

            self?.logger.debug("Tracking: \(key) waiter still pending")
            waiter(.stillPending)
        }
    }

    func takeWaiter(_ waiterId: UUID, for key: TransactionTrackingKey) -> Waiter? {
        mutex.lock()
        let waiter = waiters[key]?.removeValue(forKey: waiterId)

        if waiters[key]?.isEmpty == true {
            waiters[key] = nil
        }

        mutex.unlock()

        return waiter
    }

    func releaseBackgroundTimeIfIdle() {
        // Checked on main: an entry is registered before its keep request is posted there, so a keep that ran is seen.
        backgroundTimeKeeper?.release { [weak self] in
            guard let self else { return true }

            mutex.lock()
            let isIdle = entries.values.allSatisfy { ($0.backgroundUntil ?? .distantPast) <= Date() }
            mutex.unlock()

            return isIdle
        }
    }

    func runPickup() {
        execute(
            wrapper: pickup.createRequestsWrapper(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            switch result {
            case let .success(requests):
                requests.forEach { self?.track($0) }
            case let .failure(error):
                self?.logger.error("Tracking: pickup failed \(error)")
            }
        }
    }

    func pruneRecentlyResolved(now: Date) {
        recentlyResolved = recentlyResolved.filter {
            now.timeIntervalSince($0.value.resolvedAt) < Constants.recentlyResolvedLifetime
        }

        let overflow = recentlyResolved.count - Constants.recentlyResolvedLimit

        guard overflow > 0 else {
            return
        }

        recentlyResolved
            .sorted { $0.value.resolvedAt < $1.value.resolvedAt }
            .prefix(overflow)
            .forEach { recentlyResolved[$0.key] = nil }
    }
}

// MARK: - ApplicationHandlerDelegate

extension TransactionTrackingFacade: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        backgroundTimeKeeper?.release()

        mutex.lock()
        let watches = entries.values.filter { !$0.isResolving }.map(\.watch)
        mutex.unlock()

        watches.forEach { $0.checkNow() }

        runPickup()
    }

    func didReceiveDidEnterBackground(notification _: Notification) {
        mutex.lock()
        let backgroundUntil = entries.values.compactMap(\.backgroundUntil).max()
        mutex.unlock()

        if let backgroundUntil {
            backgroundTimeKeeper?.keepAwake(until: backgroundUntil)
        }
    }
}
