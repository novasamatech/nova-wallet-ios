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

    private var pendingFlushCompletions: [() -> Void] = []

    private var currentFeature: String?
    private var schedule = AnalyticsFlushSchedule()

    private var isWipePending: Bool = false
    private var isWipeInFlight: Bool = false
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

        consent.addObserver(with: self, queue: nil) { [weak self] oldValue, newValue in
            guard oldValue != newValue else {
                return
            }

            if newValue {
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
        static let maxBatches = 10
        static let backgroundMaxBatches = 1
    }

    func shouldRecordLocked(_ event: AnalyticsEvent) -> Bool {
        guard event.name == .featureOpened else {
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

        guard let reason = schedule.reason(forQueuedCount: count, now: now) else {
            return
        }

        flushLocked(reason: reason, now: now, completion: nil)
    }

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
            logger.warning("Analytics flush skipped, a wipe is still owed")
            wipeLocked()

            return false
        }

        guard schedule.allows(reason: reason, now: now) else {
            logger.debug("Analytics flush \(reason) held off until \(schedule.nextFlushAllowedAt)")

            return false
        }

        guard !flushCallStore.hasCall else {
            if let completion {
                pendingFlushCompletions.append(completion)
            }

            return true
        }

        if let completion {
            pendingFlushCompletions.append(completion)
        }

        schedule.recordStart(at: now)

        let maxBatches = reason == .background
            ? Constants.backgroundMaxBatches
            : Constants.maxBatches

        logger.debug("Analytics flush: \(reason)")

        executeCancellable(
            wrapper: uploader.flushWrapper(maxBatches: maxBatches),
            inOperationQueue: uploadOperationQueue,
            backingCallIn: flushCallStore,
            runningCallbackIn: nil,
            mutex: mutex
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success:
                schedule.recordSuccess()
            case let .failure(error):
                logger.debug("Analytics flush failed: \(error)")
                schedule.recordFailure(error, now: timeProvider())
            }

            releaseFlushCompletionsLocked()
        }

        return true
    }

    func releaseFlushCompletionsLocked() {
        guard !pendingFlushCompletions.isEmpty else {
            return
        }

        let pending = pendingFlushCompletions
        pendingFlushCompletions = []

        completionQueue.async {
            pending.forEach { $0() }
        }
    }

    func cancelFlushLocked() {
        flushCallStore.cancel()
        releaseFlushCompletionsLocked()
    }

    func wipeLocked() {
        isWipePending = true

        guard !isWipeInFlight else {
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

        mutex.unlock()
    }
}

// MARK: - AnalyticsTrackingProtocol

extension AnalyticsService: AnalyticsTrackingProtocol {
    public func track(_ event: AnalyticsEvent) {
        trackInternal(event, completion: nil)
    }

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

public extension AnalyticsService {
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

    func cancelFlush() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cancelFlushLocked()
    }

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

        cancelFlushLocked()

        wipeLocked()
    }

    internal func handleConsentDisabled(attestation: BackendAttestationProviderProtocol?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cancelFlushLocked()
        identity.forgetInstallId()

        wipeLocked()

        schedule.forget()
        currentFeature = nil

        attestation?.forgetClient()
    }
}
