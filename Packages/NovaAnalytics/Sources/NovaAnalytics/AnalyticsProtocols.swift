import Foundation
import Operation_iOS
import NovaAppAttest

public protocol AnalyticsEventQueueProtocol {
    func enqueueWrapper(
        name: String,
        timestamp: Date,
        payload: Data,
        consentEpoch: Int
    ) -> CompoundOperationWrapper<Void>

    func peekWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]>

    func dropOperation(ids: [String]) -> BaseOperation<Void>
    func countOperation() -> BaseOperation<Int>
    func clearOperation() -> BaseOperation<Void>
}

public protocol AnalyticsConsentManagerProtocol: AnyObject {
    var isEnabled: Bool { get }
    var isAvailable: Bool { get }
    var isPromptSeen: Bool { get }
    var isErasureOwed: Bool { get }

    func setEnabled(_ enabled: Bool)
    func setErasureOwed(_ owed: Bool)
    func markPromptSeen()
    func addObserver(with owner: AnyObject, queue: DispatchQueue?, closure: @escaping (Bool, Bool) -> Void)
    func removeObserver(by owner: AnyObject)
    func addAvailabilityObserver(with owner: AnyObject, queue: DispatchQueue?, closure: @escaping (Bool) -> Void)
    func removeAvailabilityObserver(by owner: AnyObject)
}

public protocol AnalyticsIdentityProtocol: AnyObject {
    var sessionId: String { get }

    var consentEpoch: Int { get }

    func installId() -> String?
    func existingInstallId() -> String?
    func forgetInstallId()
    func allowCreation()
}

public enum AnalyticsRemoteState: Equatable {
    case unresolved
    case enabled
    case disabled
}

public protocol AnalyticsAvailabilityProviderProtocol: AnyObject {
    var isAvailable: Bool { get }
    var remoteState: AnalyticsRemoteState { get }

    func setRemoteEnabled(_ enabled: Bool)
    func addObserver(with owner: AnyObject, queue: DispatchQueue?, closure: @escaping (Bool) -> Void)
    func removeObserver(by owner: AnyObject)
}

public protocol AnalyticsTrackingProtocol: AnyObject {
    func track(_ event: AnalyticsEvent)

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

public enum AnalyticsTransportError: Error, Equatable {
    case rejected(statusCode: Int)
    case clientError(statusCode: Int)
    case retryLater(statusCode: Int, retryAfter: TimeInterval?)
    case serverError(statusCode: Int)
}

public protocol AnalyticsUploadOperationFactoryProtocol {
    func createUploadOperation(
        bodyClosure: @escaping () throws -> Data,
        headersClosure: @escaping () throws -> [AttestationHeaderKey: String]?
    ) -> BaseOperation<Void>
}

public protocol BackgroundTaskRunning {
    func run(_ work: @escaping (@escaping () -> Void) -> Void)
}

public protocol AnalyticsSessionTracking: AnyObject {
    func setup()
    func throttle()
    func startSession()
}

public protocol AnalyticsServiceFacadeProtocol: AnalyticsTrackingProtocol {
    var consent: AnalyticsConsentManagerProtocol { get }

    func setup()
    func throttle()

    func flush(reason: AnalyticsFlushReason)
}

/// Debug-only queue inspection, kept off the production facade contract.
public protocol AnalyticsDebugInspecting: AnyObject {
    func debugPendingEventsWrapper(count: Int) -> CompoundOperationWrapper<[AnalyticsPendingEvent]>

    func debugClearPendingEventsOperation() -> BaseOperation<Void>
}
