import Foundation
import Operation_iOS
import NovaAuth

final class AnalyticsConsentAuthRecovery {
    fileprivate struct EventID: Equatable {
        let value = UUID()
        let epoch: UUID
    }

    private enum Phase { case resolving, parked, admitting, waiting }

    private struct PendingEvent {
        let id: EventID
        var phase: Phase = .resolving
        var resolutionRevision: UInt64 = 0
        var context: NovaAuthContext?
        var cancelChild: (() -> Void)?
        var timerID: UUID?
        var cancelTimer: (() -> Void)?
    }

    private let provider: AnalyticsAuthProvidingProtocol
    private let operationQueue: OperationQueue
    private let scheduler: AnalyticsConsentRecoveryScheduling
    private let isConsentEnabled: () -> Bool
    private let mutex = NSLock()
    private var epoch = UUID()
    private var pending: PendingEvent?
    private var availability = AnalyticsAuthAvailability()
    private var automaticRearms = 0
    private var isActive = false

    init(
        provider: AnalyticsAuthProvidingProtocol,
        operationQueue: OperationQueue,
        scheduler: AnalyticsConsentRecoveryScheduling = AnalyticsConsentRecoveryScheduler(),
        isConsentEnabled: @escaping () -> Bool
    ) {
        self.provider = provider
        self.operationQueue = operationQueue
        self.scheduler = scheduler
        self.isConsentEnabled = isConsentEnabled
        let current = provider.addAvailabilityObserver(self) { [weak self] in self?.receive($0) }
        receive(current)
    }

    deinit { cancel() }

    func enableConsent() {
        let current = provider.authAvailability
        let enabled = isConsentEnabled()
        mutex.lock()
        guard isActive, enabled else { mutex.unlock(); return }
        let cancellations = clearLocked()
        if current.revision > availability.revision { availability = current }
        let id = EventID(epoch: epoch)
        pending = PendingEvent(id: id)
        mutex.unlock()
        cancellations.forEach { $0() }
        resolve(id)
    }

    func cancel() {
        mutex.lock()
        epoch = UUID()
        let cancellations = clearLocked()
        mutex.unlock()
        cancellations.forEach { $0() }
    }

    func setActive(_ active: Bool) {
        mutex.lock()
        isActive = active
        if !active { epoch = UUID() }
        let cancellations = active ? [] : clearLocked()
        mutex.unlock()
        cancellations.forEach { $0() }
    }
}

private extension AnalyticsConsentAuthRecovery {
    func isCurrentLocked(_ id: EventID) -> Bool {
        isActive && pending?.id == id && epoch == id.epoch
    }

    func clearLocked() -> [() -> Void] {
        let cancellations = [pending?.cancelChild, pending?.cancelTimer].compactMap { $0 }
        pending = nil
        return cancellations
    }

    func receive(_ delivered: AnalyticsAuthAvailability) {
        let latest = provider.authAvailability
        let current = latest.revision > delivered.revision ? latest : delivered
        mutex.lock()
        guard current.revision > availability.revision else { mutex.unlock(); return }
        let invalidated = current.invalidationRevision > availability.invalidationRevision
        availability = current
        if invalidated { epoch = UUID() }
        let cancellations = invalidated ? clearLocked() : []
        let waiting = pending.flatMap { event -> EventID? in
            event.phase == .parked && current.auth != nil && current.revision > event.resolutionRevision
                ? event.id : nil
        }
        if waiting != nil { pending?.phase = .admitting }
        mutex.unlock()
        cancellations.forEach { $0() }
        if let waiting, let auth = current.auth { admit(auth, id: waiting) }
    }

    func resolve(_ id: EventID) {
        receive(provider.authAvailability)
        guard isConsentEnabled() else { finish(id); return }
        mutex.lock()
        guard isCurrentLocked(id), pending?.phase == .resolving else { mutex.unlock(); return }
        pending?.resolutionRevision = availability.revision
        mutex.unlock()

        let wrapper = provider.createAuthWrapper()
        let target = wrapper.targetOperation
        target.completionBlock = { [weak self, weak target] in
            guard let target else { return }
            target.completionBlock = nil
            let result = Result { try target.extractNoCancellableResultData() }
            self?.resolved(result, id: id)
        }
        enqueue(wrapper, id: id)
    }

    func resolved(_ result: Result<AnalyticsAuth, Error>, id: EventID) {
        receive(provider.authAvailability)
        switch result {
        case let .success(auth):
            mutex.lock()
            guard isCurrentLocked(id), pending?.phase == .resolving else { mutex.unlock(); return }
            pending?.phase = .admitting
            mutex.unlock()
            admit(auth, id: id)
        case let .failure(error):
            if canRetryResolution(error) { park(id) } else { finish(id) }
        }
    }

    func park(_ id: EventID) {
        mutex.lock()
        guard isCurrentLocked(id), pending?.phase == .resolving else { mutex.unlock(); return }
        pending?.phase = .parked
        pending?.cancelChild = nil
        let auth = availability.revision > (pending?.resolutionRevision ?? availability.revision)
            ? availability.auth : nil
        if auth != nil { pending?.phase = .admitting }
        mutex.unlock()
        if let auth { admit(auth, id: id) }
    }

    func canRetryResolution(_ error: Error) -> Bool {
        if case .parentOperationCancelled = error as? BaseOperationError { return false }
        if let error = error as? NovaAuthError {
            switch error {
            case .cancelled, .generationChanged, .unsupported, .invalidConfiguration, .transport(.cancelled):
                return false
            default:
                return true
            }
        }
        return (error as? URLError)?.code != .cancelled
    }

    func admit(_ auth: AnalyticsAuth, id: EventID) {
        guard isConsentEnabled() else { finish(id); return }
        mutex.lock()
        guard isCurrentLocked(id), pending?.phase == .admitting else { mutex.unlock(); return }
        if let context = pending?.context, context != auth.context {
            let cancellations = clearLocked()
            mutex.unlock()
            cancellations.forEach { $0() }
            return
        }
        pending?.context = auth.context
        mutex.unlock()

        let wrapper = auth.client.createAdmissionWrapper(in: auth.context, intent: .userInitiated)
        let target = wrapper.targetOperation
        target.completionBlock = { [weak self, weak target] in
            guard let target else { return }
            target.completionBlock = nil
            let result = Result { try target.extractNoCancellableResultData() }
            self?.admitted(result, id: id)
        }
        enqueue(wrapper, id: id)
    }

    func admitted(_ result: Result<Void, Error>, id: EventID) {
        if case let .failure(error) = result,
           case let .cooldown(retryAfter) = error as? NovaAuthError,
           retryAfter.isFinite {
            scheduleRetry(id, retryAfter: retryAfter)
        } else {
            finish(id)
        }
    }

    func enqueue<Value>(_ wrapper: CompoundOperationWrapper<Value>, id: EventID) {
        let enabled = isConsentEnabled()
        mutex.lock()
        guard isCurrentLocked(id), enabled else {
            mutex.unlock()
            wrapper.targetOperation.completionBlock = nil
            wrapper.cancel()
            return
        }
        pending?.cancelChild = { wrapper.cancel() }
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        mutex.unlock()
    }

    func scheduleRetry(_ id: EventID, retryAfter: TimeInterval) {
        mutex.lock()
        guard isCurrentLocked(id), pending?.phase == .admitting else { mutex.unlock(); return }
        guard automaticRearms < 2 else {
            let cancellations = clearLocked()
            mutex.unlock()
            cancellations.forEach { $0() }
            return
        }
        automaticRearms += 1
        let delay = max(TimeInterval(automaticRearms), retryAfter)
        let timerID = UUID()
        pending?.phase = .waiting
        pending?.cancelChild = nil
        pending?.timerID = timerID
        mutex.unlock()

        let cancellation = scheduler.schedule(after: delay) { [weak self] in
            self?.retry(id, timerID: timerID)
        }
        mutex.lock()
        if isCurrentLocked(id), pending?.timerID == timerID {
            pending?.cancelTimer = cancellation
            mutex.unlock()
        } else {
            mutex.unlock()
            cancellation()
        }
    }

    func retry(_ id: EventID, timerID: UUID) {
        mutex.lock()
        guard isCurrentLocked(id), pending?.timerID == timerID else { mutex.unlock(); return }
        pending?.phase = .resolving
        pending?.timerID = nil
        pending?.cancelTimer = nil
        mutex.unlock()
        resolve(id)
    }

    func finish(_ id: EventID) {
        mutex.lock()
        let cancellations = pending?.id == id && epoch == id.epoch ? clearLocked() : []
        mutex.unlock()
        cancellations.forEach { $0() }
    }
}
