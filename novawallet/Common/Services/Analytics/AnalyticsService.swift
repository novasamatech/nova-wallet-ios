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
            guard oldValue, !newValue else {
                return
            }

            self?.handleConsentDisabled(attestation: attestation)
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
            flushLocked(reason: .threshold, now: now)
        } else if now.timeIntervalSince(lastFlushAt) >= Constants.flushInterval {
            flushLocked(reason: .interval, now: now)
        }
    }

    func flushLocked(reason: AnalyticsFlushReason, now: Date) {
        guard consent.isEnabled, availability.isAvailable else {
            return
        }

        guard !flushCallStore.hasCall else {
            return
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
        }
    }
}

// MARK: - AnalyticsTrackingProtocol

extension AnalyticsService: AnalyticsTrackingProtocol {
    func track(_ event: AnalyticsEvent) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        // The one consent guard. No Date(), no UUID, no operation before this line passes.
        guard consent.isEnabled, availability.isAvailable else {
            return
        }

        guard shouldRecordLocked(event) else {
            return
        }

        let timestamp = timeProvider()

        let payload: Data

        do {
            payload = try AnalyticsCoding.encoder.encode(event.wireProperties)
        } catch {
            logger.error("Analytics event dropped, unencodable: \(error)")
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
        }
    }
}

// MARK: - Flush and wipe

extension AnalyticsService {
    func flush(reason: AnalyticsFlushReason) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        flushLocked(reason: reason, now: timeProvider())
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

        execute(
            operation: queue.clearOperation(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { _ in }
    }

    /// Spec §6.5, in order. Runs on the consent manager's true→false edge.
    func handleConsentDisabled(attestation: BackendAttestationProviderProtocol?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        flushCallStore.cancel()
        identity.forgetInstallId()

        execute(
            operation: queue.clearOperation(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { _ in }

        lastFlushAt = .distantPast
        currentFeature = nil

        // Last: the gateway's key row and client id go too, so a re-consented user is a
        // new client rather than a re-linkable one.
        attestation?.forgetClient()
    }
}
