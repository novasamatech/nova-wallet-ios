import Foundation
import Operation_iOS
import NovaAppAttest
import NovaOperationSupport
@testable import NovaAnalytics

/// Replaces `MockAnalyticsEventQueueProtocol`. Cuckoo is deliberately absent from package
/// test targets: these packages are staged for publication, and a consumer's CI must not
/// have to pull a code-generation plugin to run their tests.
final class AnalyticsEventQueueSpy: AnalyticsEventQueueProtocol {
    struct Enqueued: Equatable {
        let name: String
        let timestamp: Date
        let payload: Data
    }

    var peekResult: [AnalyticsPendingEvent] = []
    var countResult: Int = 0
    var enqueueError: Error?

    /// Runs synchronously inside `enqueueWrapper`, which is where the Cuckoo stub this
    /// replaces also ran: `AnalyticsService` composes the enqueue while still holding its
    /// mutex, and the mutual-exclusion test depends on that being the moment it fires.
    var onEnqueueComposition: ((String, Date, Data) -> Void)?

    private let mutex = NSLock()
    private var recordedEnqueued: [Enqueued] = []
    private var recordedDroppedIds: [[String]] = []
    private var recordedClearCalls = 0

    var enqueued: [Enqueued] {
        synchronised { recordedEnqueued }
    }

    var droppedIds: [[String]] {
        synchronised { recordedDroppedIds }
    }

    var clearCallCount: Int {
        synchronised { recordedClearCalls }
    }

    func enqueueWrapper(name: String, timestamp: Date, payload: Data) -> CompoundOperationWrapper<Void> {
        onEnqueueComposition?(name, timestamp, payload)

        let error = enqueueError

        return CompoundOperationWrapper(targetOperation: ClosureOperation { [weak self] in
            if let error {
                throw error
            }

            self?.synchronised {
                self?.recordedEnqueued.append(
                    Enqueued(name: name, timestamp: timestamp, payload: payload)
                )
            }
        })
    }

    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]> {
        let rows = Array(peekResult.prefix(count))

        return CompoundOperationWrapper(targetOperation: ClosureOperation { rows })
    }

    func dropOperation(ids: [String]) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.synchronised { self?.recordedDroppedIds.append(ids) }
        }
    }

    func countOperation() -> BaseOperation<Int> {
        let value = countResult

        return ClosureOperation { value }
    }

    func clearOperation() -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.synchronised { self?.recordedClearCalls += 1 }
        }
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}

/// Replaces `MockAnalyticsTrackingProtocol`. Both methods record at call time, as the
/// Cuckoo stubs did: `AnalyticsSessionTracker` calls them synchronously.
final class AnalyticsTrackingSpy: AnalyticsTrackingProtocol {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var trackedEvents: [AnalyticsEvent] = []
    private(set) var flushReasons: [AnalyticsFlushReason] = []
    private(set) var pendingCompletions: [() -> Void] = []

    var eventNames: [String] { events.map(\.name.rawValue) }

    func track(_ event: AnalyticsEvent) {
        events.append(event)
        trackedEvents.append(event)
    }

    func trackAndFlush(
        _ event: AnalyticsEvent,
        reason: AnalyticsFlushReason,
        completion: @escaping () -> Void
    ) {
        events.append(event)
        flushReasons.append(reason)
        pendingCompletions.append(completion)
    }

    func finishPendingFlushes() {
        let completions = pendingCompletions
        pendingCompletions = []
        completions.forEach { $0() }
    }
}

/// Replaces `MockAnalyticsUploading`.
///
/// `flushStub` is re-assignable mid-test because several tests re-`stub(...)` the same
/// Cuckoo mock after a first flush has already run; `maxBatchesCalls` and `reset()` stand
/// in for `verify(times:)`/`equal(to:)` and `clearInvocations`.
final class AnalyticsUploadingSpy: AnalyticsUploading {
    var flushStub: (Int) -> CompoundOperationWrapper<Void> = { _ in .createWithResult(()) }

    private let mutex = NSLock()
    private var recordedMaxBatches: [Int] = []

    var maxBatchesCalls: [Int] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return recordedMaxBatches
    }

    var flushCallCount: Int { maxBatchesCalls.count }

    func reset() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        recordedMaxBatches = []
    }

    func flushWrapper(maxBatches: Int) -> CompoundOperationWrapper<Void> {
        mutex.lock()
        recordedMaxBatches.append(maxBatches)
        mutex.unlock()

        return flushStub(maxBatches)
    }
}

/// Replaces `MockAnalyticsUploadOperationFactoryProtocol`.
///
/// The closures are recorded when the operation is *composed*, which is where the Cuckoo
/// `ArgumentCaptor` picked them up; `onBody` fires when the operation actually runs the
/// body closure, which is the distinction the abort path turns on — a consent gate that
/// throws inside `bodyClosure` leaves nothing recorded there even though the operation was
/// constructed.
final class AnalyticsUploadOperationFactorySpy: AnalyticsUploadOperationFactoryProtocol {
    /// Consumed one per batch, so a test can script a 2xx then a 500.
    var uploadResults: [Result<Void, Error>] = []
    var onBody: ((Data) -> Void)?

    private let mutex = NSLock()
    private var recordedBodyClosures: [() throws -> Data] = []
    private var recordedHeaderClosures: [() throws -> [AttestationHeaderKey: String]?] = []

    var bodyClosures: [() throws -> Data] {
        synchronised { recordedBodyClosures }
    }

    var headerClosures: [() throws -> [AttestationHeaderKey: String]?] {
        synchronised { recordedHeaderClosures }
    }

    var callCount: Int {
        synchronised { recordedBodyClosures.count }
    }

    func createUploadOperation(
        bodyClosure: @escaping () throws -> Data,
        headersClosure: @escaping () throws -> [AttestationHeaderKey: String]?
    ) -> BaseOperation<Void> {
        synchronised {
            recordedBodyClosures.append(bodyClosure)
            recordedHeaderClosures.append(headersClosure)
        }

        let next: Result<Void, Error> = synchronised {
            uploadResults.isEmpty ? .success(()) : uploadResults.removeFirst()
        }

        let onBody = onBody

        return ClosureOperation {
            // Forces the body closure, so a consent gate inside it is exercised exactly as
            // `NetworkOperation.main()` would exercise it.
            onBody?(try bodyClosure())

            try next.get()
        }
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}

/// Replaces `MockBackendAttestationProviderProtocol`. Lives in the analytics test target
/// because that is where it is consumed, even though the protocol belongs to NovaAppAttest.
///
/// `headersStub` runs inside the returned operation rather than at composition time, so a
/// test can opt out from within it — the exact window `AnalyticsUploader`'s consent gate
/// exists to close.
final class BackendAttestationProviderSpy: BackendAttestationProviderProtocol {
    /// `nil` models mode `.none` — the request goes out unsigned.
    var headersStub: () throws -> [AttestationHeaderKey: String]? = {
        [.clientId: "cid", .challenge: "chal", .signature: "sig"]
    }

    /// Runs inside the operation, before the body closure: where the opt-out tests inject
    /// an opt-out mid-round-trip.
    var onSigning: (() -> Void)?

    private let mutex = NSLock()
    private var recordedBodyClosures: [() throws -> Data] = []
    private var recordedBodies: [Data] = []
    private var recordedMarkUnattested = 0
    private var recordedForgetClient = 0
    private var recordedAllowClient = 0

    /// The closures the uploader handed over, captured when the wrapper was composed.
    var signedBodyClosures: [() throws -> Data] {
        synchronised { recordedBodyClosures }
    }

    /// The bodies the uploader actually asked to sign. Asserting on these is how the tests
    /// prove the envelope was built before signing, not after.
    var signedBodies: [Data] {
        synchronised { recordedBodies }
    }

    var signingCallCount: Int {
        synchronised { recordedBodyClosures.count }
    }

    var markUnattestedCallCount: Int {
        synchronised { recordedMarkUnattested }
    }

    var forgetClientCallCount: Int {
        synchronised { recordedForgetClient }
    }

    var allowClientCallCount: Int {
        synchronised { recordedAllowClient }
    }

    func createSignedHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        synchronised { recordedBodyClosures.append(bodyClosure) }

        let stub = headersStub
        let hook = onSigning

        // A fresh wrapper per call: one instance cannot run twice.
        return CompoundOperationWrapper(
            targetOperation: ClosureOperation<[AttestationHeaderKey: String]?> { [weak self] in
                hook?()

                let body = try bodyClosure()

                self?.synchronised { self?.recordedBodies.append(body) }

                return try stub()
            }
        )
    }

    func markUnattested() {
        synchronised { recordedMarkUnattested += 1 }
    }

    func forgetClient() {
        synchronised { recordedForgetClient += 1 }
    }

    func allowClient() {
        synchronised { recordedAllowClient += 1 }
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}
