import Foundation
import Operation_iOS

final class AnalyticsService {
    private let consent: AnalyticsConsentManagerProtocol
    private let availability: AnalyticsAvailabilityProviderProtocol
    private let queue: AnalyticsEventQueueProtocol
    private let identity: AnalyticsIdentityProtocol
    private let uploader: AnalyticsUploading
    private let operationQueue: OperationQueue
    private let uploadOperationQueue: OperationQueue
    private let timeProvider: () -> Date
    private let logger: LoggerProtocol

    private let mutex = NSLock()
    private let flushCallStore = CancellableCallStore()

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

    init(
        consent: AnalyticsConsentManagerProtocol,
        availability: AnalyticsAvailabilityProviderProtocol,
        queue: AnalyticsEventQueueProtocol,
        identity: AnalyticsIdentityProtocol,
        uploader: AnalyticsUploading,
        attestation: BackendAttestationProviderProtocol? = nil,
        operationQueue: OperationQueue,
        uploadOperationQueue: OperationQueue,
        timeProvider: @escaping () -> Date = { Date() },
        logger: LoggerProtocol = Logger.shared
    ) {
        self.consent = consent
        self.availability = availability
        self.queue = queue
        self.identity = identity
        self.uploader = uploader
        self.operationQueue = operationQueue
        self.uploadOperationQueue = uploadOperationQueue
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

    /// Returns false when nothing was started, so the caller knows to run `completion`
    /// itself rather than wait for a chain that does not exist.
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
            return false
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

            completion?()
        }

        return true
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

        mutex.unlock()

        let payload: Data

        do {
            payload = try AnalyticsCoding.encoder.encode(event.wireProperties)
        } catch {
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
    }
}

// MARK: - AnalyticsTrackingProtocol

extension AnalyticsService: AnalyticsTrackingProtocol {
    func track(_ event: AnalyticsEvent) {
        trackInternal(event, completion: nil)
    }

    /// `track` and `flush` are both fire-and-forget, so calling them back to back leaves
    /// the enqueue racing the peek that is meant to pick it up — and, on the background
    /// path, lets the `UIBackgroundTask` end before either has run.
    func trackAndFlush(
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
    func flush(reason: AnalyticsFlushReason) {
        flush(reason: reason, completion: {})
    }

    func flush(reason: AnalyticsFlushReason, completion: @escaping () -> Void) {
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
    func cancelFlush() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        flushCallStore.cancel()
    }

    /// Spec §10. The kill switch's one-shot wipe, on the enabled→disabled edge only:
    /// rows left by a previous, still-enabled process are cleared once, and a build that
    /// was never available has nothing of its own to clear.
    func handleAvailabilityChanged() {
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
        flushCallStore.cancel()

        wipeLocked()
    }

    /// Spec §6.5, in order. Runs on the consent manager's true→false edge.
    func handleConsentDisabled(attestation: BackendAttestationProviderProtocol?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        flushCallStore.cancel()
        identity.forgetInstallId()

        wipeLocked()

        lastFlushAt = .distantPast
        currentFeature = nil

        // Last: the gateway's key row and client id go too, so a re-consented user is a
        // new client rather than a re-linkable one.
        attestation?.forgetClient()
    }
}
