import Foundation
import Operation_iOS

final class AnalyticsConsentAuthRecovery {
    private let provider: AnalyticsAuthProvidingProtocol
    private let operationQueue: OperationQueue
    private let isConsentEnabled: () -> Bool
    private let mutex = NSLock()
    private var event = UUID()
    private var cancelChild: (() -> Void)?
    private var isActive = false

    init(
        provider: AnalyticsAuthProvidingProtocol,
        operationQueue: OperationQueue,
        isConsentEnabled: @escaping () -> Bool
    ) {
        self.provider = provider
        self.operationQueue = operationQueue
        self.isConsentEnabled = isConsentEnabled
    }

    deinit { cancel() }

    func enableConsent() {
        mutex.lock()
        guard isActive, isConsentEnabled() else { mutex.unlock(); return }
        let cancellation = cancelChild
        cancelChild = nil
        self.event = UUID()
        let event = self.event
        mutex.unlock()
        cancellation?()
        let wrapper = provider.createAuthWrapper()
        let target = wrapper.targetOperation
        target.completionBlock = { [weak self, weak target] in
            target?.completionBlock = nil
            guard let self, let auth = try? target?.extractNoCancellableResultData() else { return }
            self.admit(auth, event: event)
        }
        enqueue(wrapper, event: event)
    }

    func cancel() {
        mutex.lock()
        event = UUID()
        let cancellation = cancelChild
        cancelChild = nil
        mutex.unlock()
        cancellation?()
    }

    func setActive(_ active: Bool) {
        mutex.lock()
        isActive = active
        if !active { event = UUID() }
        let cancellation = active ? nil : cancelChild
        if !active { cancelChild = nil }
        mutex.unlock()
        cancellation?()
    }
}

private extension AnalyticsConsentAuthRecovery {
    func admit(_ auth: AnalyticsAuth, event: UUID) {
        mutex.lock()
        let isCurrent = isActive && self.event == event && isConsentEnabled()
        mutex.unlock()
        guard isCurrent else { return }
        let wrapper = auth.client.createAdmissionWrapper(in: auth.context, intent: .userInitiated)
        let target = wrapper.targetOperation
        target.completionBlock = { [weak self, weak target] in
            target?.completionBlock = nil
            self?.finish(event: event)
        }
        enqueue(wrapper, event: event)
    }

    func enqueue<Value>(_ wrapper: CompoundOperationWrapper<Value>, event: UUID) {
        mutex.lock()
        defer { mutex.unlock() }
        guard isActive, self.event == event, isConsentEnabled() else {
            wrapper.targetOperation.completionBlock = nil
            return
        }
        cancelChild = { wrapper.cancel() }
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func finish(event: UUID) {
        mutex.lock()
        defer { mutex.unlock() }
        if self.event == event { cancelChild = nil }
    }
}
