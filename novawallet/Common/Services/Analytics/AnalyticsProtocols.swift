import Foundation
import Operation_iOS
import NovaAppAttest

protocol AnalyticsEventQueueProtocol {
    /// Allocates the next sequence, persists the row, then trims to the newest `maxCount`.
    func enqueueWrapper(name: String, timestamp: Date, payload: Data) -> CompoundOperationWrapper<Void>

    /// The oldest `count` rows, in insertion order.
    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]>

    func dropOperation(ids: [String]) -> BaseOperation<Void>
    func countOperation() -> BaseOperation<Int>
    func clearOperation() -> BaseOperation<Void>
}

protocol AnalyticsConsentManagerProtocol: AnyObject {
    var isEnabled: Bool { get }
    /// Forwarded from the availability provider, so the guard reads one object.
    var isAvailable: Bool { get }
    var isPromptSeen: Bool { get }

    func setEnabled(_ enabled: Bool)
    func markPromptSeen()
    func addObserver(with owner: AnyObject, queue: DispatchQueue?, closure: @escaping (Bool, Bool) -> Void)
    func removeObserver(by owner: AnyObject)
}

protocol AnalyticsIdentityProtocol: AnyObject {
    var sessionId: String { get }

    /// Increments on every consent-cycle boundary. Read it — never `installId()` — when
    /// re-checking consent from inside an already-composed chain: `installId()` mints.
    var consentEpoch: Int { get }

    /// Created on first call, never before. `nil` once forgotten and not re-armed.
    func installId() -> String?
    func forgetInstallId()
    func allowCreation()
}

protocol AnalyticsAvailabilityProviderProtocol: AnyObject {
    var isAvailable: Bool { get }
}

protocol AnalyticsTrackingProtocol: AnyObject {
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

enum AnalyticsFlushReason {
    case threshold
    case interval
    case launch
    case background
    case manual
}

protocol AnalyticsUploading: AnyObject {
    func flushWrapper(maxBatches: Int) -> CompoundOperationWrapper<Void>
}

/// Spec §6.3. A raw result factory produces these, because `successResponseBlock:`
/// collapses 403 into `unexpectedStatusCode` and `processingBlock:` fails an empty 2xx.
enum AnalyticsTransportError: Error, Equatable {
    case rejected(statusCode: Int)
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
}

protocol AnalyticsUploadOperationFactoryProtocol {
    func createUploadOperation(
        bodyClosure: @escaping () throws -> Data,
        headersClosure: @escaping () throws -> [AttestationHeaderKey: String]?
    ) -> BaseOperation<Void>
}

protocol BackgroundTaskRunning {
    /// Calls `work` with a completion the caller must invoke; the runner ends the
    /// system task when it fires or when the task expires.
    func run(_ work: @escaping (@escaping () -> Void) -> Void)
}

protocol AnalyticsSessionTracking: AnyObject {
    func setup()
    func throttle()
    func startSession()
}

protocol AnalyticsServiceFacadeProtocol: AnalyticsTrackingProtocol, ApplicationServiceProtocol {
    var consent: AnalyticsConsentManagerProtocol { get }

    func flush(reason: AnalyticsFlushReason)
}
