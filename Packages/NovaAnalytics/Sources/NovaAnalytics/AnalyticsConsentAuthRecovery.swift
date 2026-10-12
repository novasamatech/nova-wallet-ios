import Foundation
import Operation_iOS
import NovaAuth

final class AnalyticsConsentAuthRecovery {
    fileprivate struct EventID: Equatable {
        let value = UUID()
        let epoch: UUID
    }

    private struct PendingEvent {
        let id: EventID
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
    private var rounds = 0
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
        provider.addContextObserver(self) { [weak self] in self?.cancel() }
    }

    deinit { cancel() }

    func enableConsent() {
        mutex.lock()
        guard isActive, isConsentEnabled() else { mutex.unlock(); return }
        let cancellations = clearLocked()
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
        isActive && pending?.id == id && epoch == id.epoch && isConsentEnabled()
    }

    func clearLocked() -> [() -> Void] {
        let cancellations = [pending?.cancelChild, pending?.cancelTimer].compactMap { $0 }
        pending = nil
        return cancellations
    }

    func resolve(_ id: EventID) {
        mutex.lock()
        guard isCurrentLocked(id) else { mutex.unlock(); return }
        guard rounds < 3 else {
            let cancellations = clearLocked()
            mutex.unlock()
            cancellations.forEach { $0() }
            return
        }
        rounds += 1
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
        switch result {
        case let .success(auth):
            admit(auth, id: id)
        case let .failure(error):
            if canRetryResolution(error) { scheduleRetry(id, retryAfter: 0) } else { finish(id) }
        }
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
        mutex.lock()
        guard isCurrentLocked(id) else { mutex.unlock(); return }
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
        mutex.lock()
        guard isCurrentLocked(id) else {
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
        guard isCurrentLocked(id) else { mutex.unlock(); return }
        guard rounds < 3 else {
            let cancellations = clearLocked()
            mutex.unlock()
            cancellations.forEach { $0() }
            return
        }
        let delay = max(TimeInterval(rounds), retryAfter)
        let timerID = UUID()
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
