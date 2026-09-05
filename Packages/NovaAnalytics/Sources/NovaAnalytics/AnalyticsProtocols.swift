import Foundation
import Operation_iOS
import NovaAppAttest

public protocol AnalyticsEventQueueProtocol {
    /// Allocates the next sequence, persists the row, then trims to the newest `maxCount`.
    func enqueueWrapper(name: String, timestamp: Date, payload: Data) -> CompoundOperationWrapper<Void>

    /// The oldest `count` rows, in insertion order.
    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]>

    func dropOperation(ids: [String]) -> BaseOperation<Void>
    func countOperation() -> BaseOperation<Int>
    func clearOperation() -> BaseOperation<Void>
}

public protocol AnalyticsConsentManagerProtocol: AnyObject {
    var isEnabled: Bool { get }
    /// Forwarded from the availability provider, so the guard reads one object.
    var isAvailable: Bool { get }
    var isPromptSeen: Bool { get }

    func setEnabled(_ enabled: Bool)
    func markPromptSeen()
    func addObserver(with owner: AnyObject, queue: DispatchQueue?, closure: @escaping (Bool, Bool) -> Void)
    func removeObserver(by owner: AnyObject)
}

public protocol AnalyticsIdentityProtocol: AnyObject {
    var sessionId: String { get }

    /// Increments on every consent-cycle boundary. Read it — never `installId()` — when
    /// re-checking consent from inside an already-composed chain: `installId()` mints.
    var consentEpoch: Int { get }

    /// Created on first call, never before. `nil` once forgotten and not re-armed.
    func installId() -> String?
    func forgetInstallId()
    func allowCreation()
}

public protocol AnalyticsAvailabilityProviderProtocol: AnyObject {
    var isAvailable: Bool { get }
}

public protocol AnalyticsTrackingProtocol: AnyObject {
    func track(_ event: AnalyticsEvent)

    /// Enqueues `event`, then flushes, calling `completion` once the flush chain has
    /// settled. The background path needs it because both halves are fire-and-forget:
    /// without it the `UIBackgroundTask` ends before the row is written.
    func trackAndFlush(
        _ event: AnalyticsEvent,
        reason: AnalyticsFlushReason,
        completion: @escaping () -> Void
    )
}

public enum AnalyticsFlushReason {
    case threshold
    case interval
    case launch
    case background
    case manual
}

public protocol AnalyticsUploading: AnyObject {
    func flushWrapper(maxBatches: Int) -> CompoundOperationWrapper<Void>
}

/// Spec §6.3. A raw result factory produces these, because `successResponseBlock:`
/// collapses 403 into `unexpectedStatusCode` and `processingBlock:` fails an empty 2xx.
public enum AnalyticsTransportError: Error, Equatable {
    case rejected(statusCode: Int)
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
}

public protocol AnalyticsUploadOperationFactoryProtocol {
    func createUploadOperation(
        bodyClosure: @escaping () throws -> Data,
        headersClosure: @escaping () throws -> [AttestationHeaderKey: String]?
    ) -> BaseOperation<Void>
}

public protocol BackgroundTaskRunning {
    /// Calls `work` with a completion the caller must invoke; the runner ends the
    /// system task when it fires or when the task expires.
    func run(_ work: @escaping (@escaping () -> Void) -> Void)
}

public protocol AnalyticsSessionTracking: AnyObject {
    func setup()
    func throttle()
    func startSession()
}

public protocol AnalyticsServiceFacadeProtocol: AnalyticsTrackingProtocol {
    var consent: AnalyticsConsentManagerProtocol { get }

    /// `ApplicationServiceProtocol` is app-defined and cannot cross the boundary, so the
    /// two members are declared here directly. `RootInteractor` calls `setup()` on the
    /// concrete facade type and is unaffected.
    func setup()
    func throttle()

    func flush(reason: AnalyticsFlushReason)

    /// Read-only view of the pending queue for a host's debug tooling. Routed through the
    /// facade rather than exposing the store, so a caller observes the same queue instance
    /// as everything else — one lock, one call store, one session.
    func debugPendingEventsWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]>

    /// Discards the pending queue, for that same tooling. Narrow on purpose: the queue
    /// itself stays unexposed, because `enqueueWrapper` would let a host write rows that
    /// never passed the consent gate.
    func debugClearPendingEventsOperation() -> BaseOperation<Void>
}
