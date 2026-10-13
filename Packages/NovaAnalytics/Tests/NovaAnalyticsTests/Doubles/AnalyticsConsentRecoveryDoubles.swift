import Foundation
import XCTest
import NovaAuth
import Operation_iOS
@testable import NovaAnalytics

final class ConsentRecoveryQueue: OperationQueue, @unchecked Sendable {
    private let completions = DispatchGroup()

    override func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        for operation in ops {
            completions.enter()
            let completion = operation.completionBlock
            operation.completionBlock = { [completions] in
                completion?()
                completions.leave()
            }
        }
        super.addOperations(ops, waitUntilFinished: wait)
    }

    func drain(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(completions.wait(timeout: .now() + 5), .success, file: file, line: line)
    }
}

final class ConsentRecoveryScheduler: AnalyticsConsentRecoveryScheduling {
    final class Entry {
        let delay: TimeInterval
        let action: () -> Void
        let cancelled = Locked(false)

        init(delay: TimeInterval, action: @escaping () -> Void) {
            self.delay = delay
            self.action = action
        }
    }

    private let entries = Locked<[Entry]>([])
    var scheduled: [Entry] { entries.value }
    var onCancel: (() -> Void)?

    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        let entry = Entry(delay: delay, action: action)
        entries.update { $0.append(entry) }
        return { [onCancel] in
            entry.cancelled.update { $0 = true }
            onCancel?()
        }
    }

    func fire(_ index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let entries = scheduled
        guard entries.indices.contains(index) else {
            return XCTFail("Scheduled retry is missing", file: file, line: line)
        }
        let entry = entries[index]
        if !entry.cancelled.value { entry.action() }
    }
}

final class ConsentRecoveryProvider: AnalyticsAuthProvidingProtocol {
    private let recordedRequests = Locked(0)
    var requests: Int { recordedRequests.value }
    var resolve: () throws -> AnalyticsAuth
    var onCreate: (() -> Void)?
    var createWrapper: (() -> CompoundOperationWrapper<AnalyticsAuth>)?
    private let mutex = NSLock()
    private var availability = AnalyticsAuthAvailability()
    private var observer: ((AnalyticsAuthAvailability) -> Void)?

    init(auth: AnalyticsAuth) { resolve = { auth } }

    var authAvailability: AnalyticsAuthAvailability {
        mutex.lock()
        defer { mutex.unlock() }
        return availability
    }

    func addAvailabilityObserver(
        _: AnyObject,
        closure: @escaping (AnalyticsAuthAvailability) -> Void
    ) -> AnalyticsAuthAvailability {
        mutex.lock()
        defer { mutex.unlock() }
        observer = closure
        return availability
    }

    func publish(_ auth: AnalyticsAuth?, invalidated: Bool = false) {
        mutex.lock()
        availability = AnalyticsAuthAvailability(
            revision: availability.revision + 1,
            invalidationRevision: availability.invalidationRevision + (invalidated ? 1 : 0),
            auth: auth
        )
        let current = availability
        let callback = observer
        mutex.unlock()
        callback?(current)
    }

    func createAuthWrapper() -> CompoundOperationWrapper<AnalyticsAuth> {
        recordedRequests.update { $0 += 1 }
        onCreate?()
        if let createWrapper { return createWrapper() }
        return CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in try resolve() })
    }
}

final class ConsentRecoveryPendingResolution {
    private let completion = Locked<((Result<AnalyticsAuth, Error>) -> Void)?>(nil)
    let cancelled = Locked(false)
    var onStart: (() -> Void)?
    var onCancel: (() -> Void)?

    func createWrapper() -> CompoundOperationWrapper<AnalyticsAuth> {
        let operation = AsyncClosureOperation<AnalyticsAuth>(
            operationClosure: { [self] callback in
                completion.update { $0 = callback }
                onStart?()
            },
            cancelationClosure: { [self] in
                cancelled.update { $0 = true }
                onCancel?()
            }
        )
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func resolve(_ auth: AnalyticsAuth) {
        var callback: ((Result<AnalyticsAuth, Error>) -> Void)?
        completion.update {
            callback = $0
            $0 = nil
        }
        callback?(.success(auth))
    }
}

final class ConsentRecoveryClient: NovaAuthClientProtocol {
    let isSupported = true
    private let recordedContexts = Locked<[NovaAuthContext]>([])
    var contexts: [NovaAuthContext] { recordedContexts.value }
    var result: Result<Void, Error> = .success(())

    func createAdmissionWrapper(in context: NovaAuthContext, intent: NovaAuthRequestIntent) -> CompoundOperationWrapper<Void> {
        XCTAssertEqual(intent, .userInitiated)
        return CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in
            recordedContexts.update { $0.append(context) }
            try result.get()
        })
    }

    func createResponseWrapper(
        for _: NovaAuthRequest,
        beforeSend _: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        XCTFail("Unexpected upload")
        return .createWithError(NovaAuthError.invalidRequest)
    }
}

final class ConsentRecoveryHarness {
    let queue = ConsentRecoveryQueue()
    let scheduler = ConsentRecoveryScheduler()
    let client = ConsentRecoveryClient()
    let enabled = Locked(true)
    let provider: ConsentRecoveryProvider
    let recovery: AnalyticsConsentAuthRecovery

    init() {
        provider = ConsentRecoveryProvider(auth: analyticsTestAuth(client))
        recovery = AnalyticsConsentAuthRecovery(
            provider: provider,
            operationQueue: queue,
            scheduler: scheduler,
            isConsentEnabled: { [enabled] in enabled.value }
        )
        recovery.setActive(true)
    }

    func enable() { recovery.enableConsent(); queue.drain() }
    func retry(_ index: Int) { scheduler.fire(index); queue.drain() }
}
