import Foundation
import Operation_iOS
import SDKLogger
import NovaAppAttest

public final class AnalyticsService {
    private let consent: AnalyticsConsentManagerProtocol
    private let availability: AnalyticsAvailabilityProviderProtocol
    private let queue: AnalyticsEventQueueProtocol
    private let identity: AnalyticsIdentityProtocol
    private let uploader: AnalyticsUploading
    private let operationQueue: OperationQueue
    private let uploadOperationQueue: OperationQueue
    private let completionQueue: DispatchQueue
    private let timeProvider: () -> Date
    private let logger: SDKLoggerProtocol

    private let mutex = NSLock()
    private let flushCallStore = CancellableCallStore()

    /// Owned here rather than captured by `executeCancellable`'s callback, which is
    /// silently dropped once the call store has been cancelled — that would strand the
    /// caller's completion, and with it the `UIBackgroundTask` the background flush holds.
    private var pendingFlushCompletions: [() -> Void] = []

    private var currentFeature: String?
    private var lastFlushAt: Date = .distantPast

    /// Set when a wipe is issued, cleared only when it comes back successful. While it is
    /// set no flush may run: a wipe that failed leaves pre-opt-out rows in the store, and
    /// uploading them after re-consent would send data the user asked to have deleted
    /// under the identity that replaced theirs.
    private var isWipePending: Bool = false
    private var isWipeInFlight: Bool = false
    /// Seeded from the provider so the kill switch's enabled→disabled edge is detected
    /// even though the config that flips it only arrives after `setup()`.
    private var wasAvailable: Bool

    public init(
        consent: AnalyticsConsentManagerProtocol,
        availability: AnalyticsAvailabilityProviderProtocol,
        queue: AnalyticsEventQueueProtocol,
        identity: AnalyticsIdentityProtocol,
        uploader: AnalyticsUploading,
        attestation: BackendAttestationProviderProtocol? = nil,
        operationQueue: OperationQueue,
        uploadOperationQueue: OperationQueue,
        completionQueue: DispatchQueue = DispatchQueue(label: "io.novawallet.analytics.completions"),
        timeProvider: @escaping () -> Date = { Date() },
        logger: SDKLoggerProtocol
    ) {
        self.consent = consent
        self.availability = availability
        self.queue = queue
        self.identity = identity
        self.uploader = uploader
        self.operationQueue = operationQueue
        self.uploadOperationQueue = uploadOperationQueue
        self.completionQueue = completionQueue
        self.timeProvider = timeProvider
        self.logger = logger

        wasAvailable = availability.isAvailable

        // The wipe lives next to the state it wipes, so opting out is guaranteed even
        // when nothing composed this service into a facade.
        consent.addObserver(with: self, queue: nil) { [weak self] oldValue, newValue in
            guard oldValue != newValue else {
                return
            }

            if newValue {
                // Re-arm the identities that opting out latched shut, so a re-consented
                // user gets a brand new install id and gateway client rather than none.
                self?.identity.allowCreation()
                attestation?.allowClient()
            } else {
                self?.handleConsentDisabled(attestation: attestation)
            }
        }
    }

    deinit {
        consent.removeObserver(by: self)
    }
}

// MARK: - Private

private extension AnalyticsService {
    enum Constants {
        static let flushThreshold = 50
        static let flushInterval: TimeInterval = 300
        static let maxBatches = 10
        static let backgroundMaxBatches = 1
    }

    /// Returns false when the event is collapsed away. Must be called under the mutex.
    func shouldRecordLocked(_ event: AnalyticsEvent) -> Bool {
        guard event.name == .featureOpened else {
            // An untracked screen leaves currentFeature alone, so returning from a
            // detail does not re-fire feature_opened.
            return true
        }

        guard case let .enumerated(feature)? = event.properties[.featureId] else {
            return true
        }

        guard feature != currentFeature else {
            return false
        }

        currentFeature = feature

        return true
    }

    func flushIfNeededLocked(count: Int) {
        let now = timeProvider()

        if count >= Constants.flushThreshold {
            flushLocked(reason: .threshold, now: now, completion: nil)
        } else if now.timeIntervalSince(lastFlushAt) >= Constants.flushInterval {
            flushLocked(reason: .interval, now: now, completion: nil)
        }
    }

    /// Returns false when no chain will ever settle for this caller, so it must run
    /// `completion` itself. True means the completion has been parked and will be run
    /// exactly once — by the chain finishing, or by whatever cancels it.
    @discardableResult
    func flushLocked(
        reason: AnalyticsFlushReason,
        now: Date,
        completion: (() -> Void)?
    ) -> Bool {
        guard consent.isEnabled, availability.isAvailable else {
            return false
        }

        guard !isWipePending else {
            // Retry the wipe instead: the rows still in the store are the ones the user
            // asked to be rid of.
            logger.warning("Analytics flush skipped, a wipe is still owed")
            wipeLocked()

            return false
        }

        guard !flushCallStore.hasCall else {
            // Single-flight: wait for the chain that is already running rather than
            // reporting settled while a POST is still on the wire — releasing the
            // background assertion here is the very hazard this method exists to close.
            if let completion {
                pendingFlushCompletions.append(completion)
            }

            return true
        }

        if let completion {
            pendingFlushCompletions.append(completion)
        }

        lastFlushAt = now

        let maxBatches = reason == .background
            ? Constants.backgroundMaxBatches
            : Constants.maxBatches

        logger.debug("Analytics flush: \(reason)")

        // The upload runs on the shared network queue, never on the serial persistence
        // queue: an event must be storable while a 15 s POST is in flight.
        executeCancellable(
            wrapper: uploader.flushWrapper(maxBatches: maxBatches),
            inOperationQueue: uploadOperationQueue,
            backingCallIn: flushCallStore,
            runningCallbackIn: nil,
            mutex: mutex
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.debug("Analytics flush failed: \(error)")
            }

            // Runs with `mutex` held — see `executeCancellable`'s `locking:` argument.
            self?.releaseFlushCompletionsLocked()
        }

        return true
    }

    /// `executeCancellable` drops its callback once the call store has been cancelled, so
    /// the completions cannot live there. Both routes out of a flush — the chain settling
    /// and the chain being cancelled — end here, and the list is emptied before anything
    /// runs, so each completion fires exactly once.
    func releaseFlushCompletionsLocked() {
        guard !pendingFlushCompletions.isEmpty else {
            return
        }

        let pending = pendingFlushCompletions
        pendingFlushCompletions = []

        // Off the mutex: a completion is the caller's code, and NSLock is not recursive,
        // so a completion that flushes or tracks again would deadlock here.
        completionQueue.async {
            pending.forEach { $0() }
        }
    }

    func cancelFlushLocked() {
        flushCallStore.cancel()
        releaseFlushCompletionsLocked()
    }

    /// Spec §6.5 step 3 and §10's one-shot wipe. Failure is latched rather than logged and
    /// forgotten, so the next flush attempt retries it instead of uploading what should
    /// already be gone.
    func wipeLocked() {
        isWipePending = true

        guard !isWipeInFlight else {
            // The clear already running deletes everything the retry would.
            return
        }

        isWipeInFlight = true

        execute(
            operation: queue.clearOperation(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            isWipeInFlight = false

            switch result {
            case .success:
                isWipePending = false
            case let .failure(error):
                logger.error("Analytics queue wipe failed, retrying on the next flush: \(error)")
            }
        }
    }

    func trackInternal(_ event: AnalyticsEvent, completion: (() -> Void)?) {
        mutex.lock()

        // The one consent guard. No Date(), no UUID, no operation before this line passes.
        guard consent.isEnabled, availability.isAvailable, shouldRecordLocked(event) else {
            mutex.unlock()
            completion?()

            return
        }

        let timestamp = timeProvider()

        let payload: Data

        do {
            payload = try AnalyticsCoding.encoder.encode(event.wireProperties)
        } catch {
            mutex.unlock()
            logger.error("Analytics event dropped, unencodable: \(error)")
            completion?()

            return
        }

        let enqueueWrapper = queue.enqueueWrapper(
            name: event.name.rawValue,
            timestamp: timestamp,
            payload: payload
        )

        let countOperation = queue.countOperation()
        countOperation.addDependency(enqueueWrapper.targetOperation)

        // The flush decision is an operation on the same serial queue rather than a
        // completion block, so it is ordered against the enqueue that produced the count
        // instead of racing whatever thread Foundation happens to run completions on.
        let flushDecisionOperation = ClosureOperation<Void> { [weak self] in
            let count = try countOperation.extractNoCancellableResultData()

            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            flushIfNeededLocked(count: count)
        }

        flushDecisionOperation.addDependency(countOperation)

        let totalWrapper = CompoundOperationWrapper(
            targetOperation: flushDecisionOperation,
            dependencies: enqueueWrapper.allOperations + [countOperation]
        )

        // Submitted while the mutex is still held, so it is ordered against the wipes in
        // `handleConsentDisabled` and `handleAvailabilityChanged`, which submit their clear
        // to the same serial queue under the same lock. Releasing the lock first let an
        // event land in the store *after* the opt-out wipe had already run.
        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Analytics enqueue failed: \(error)")
            }

            completion?()
        }

        mutex.unlock()
    }
}

// MARK: - AnalyticsTrackingProtocol

extension AnalyticsService: AnalyticsTrackingProtocol {
    public func track(_ event: AnalyticsEvent) {
        trackInternal(event, completion: nil)
    }

    /// `track` and `flush` are both fire-and-forget, so calling them back to back leaves
    /// the enqueue racing the peek that is meant to pick it up — and, on the background
    /// path, lets the `UIBackgroundTask` end before either has run.
    public func trackAndFlush(
        _ event: AnalyticsEvent,
        reason: AnalyticsFlushReason,
        completion: @escaping () -> Void
    ) {
        trackInternal(event) { [weak self] in
            guard let self else {
                completion()

                return
            }

            flush(reason: reason, completion: completion)
        }
    }
}

// MARK: - Flush and wipe

extension AnalyticsService {
    public func flush(reason: AnalyticsFlushReason) {
        flush(reason: reason, completion: {})
    }

    public func flush(reason: AnalyticsFlushReason, completion: @escaping () -> Void) {
        mutex.lock()
        let started = flushLocked(reason: reason, now: timeProvider(), completion: completion)
        mutex.unlock()

        guard !started else {
            return
        }

        completion()
    }

    /// Spec §3.2. The facade's `throttle()` is symmetric, so an in-flight flush is
    /// abandoned rather than left holding the single-flight slot for the rest of the
    /// process, which would swallow every later flush.
    public func cancelFlush() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cancelFlushLocked()
    }

    /// Spec §10. The kill switch's one-shot wipe, on the enabled→disabled edge only:
    /// rows left by a previous, still-enabled process are cleared once, and a build that
    /// was never available has nothing of its own to clear.
    public func handleAvailabilityChanged() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let isAvailable = availability.isAvailable

        defer {
            wasAvailable = isAvailable
        }

        guard wasAvailable, !isAvailable else {
            return
        }

        // Same hazard as the opt-out wipe: a batch already in the air must not be dropped
        // from a queue that is being cleared underneath it.
        cancelFlushLocked()

        wipeLocked()
    }

    /// Spec §6.5, in order. Runs on the consent manager's true→false edge.
    func handleConsentDisabled(attestation: BackendAttestationProviderProtocol?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cancelFlushLocked()
        identity.forgetInstallId()

        wipeLocked()

        lastFlushAt = .distantPast
        currentFeature = nil

        // Last: the gateway's key row and client id go too, so a re-consented user is a
        // new client rather than a re-linkable one.
        attestation?.forgetClient()
    }
}
