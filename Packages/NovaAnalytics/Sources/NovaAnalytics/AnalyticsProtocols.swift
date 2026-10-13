import Foundation
import Operation_iOS

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

public protocol AnalyticsAvailabilityProviderProtocol: AnyObject {
    var isAvailable: Bool { get }

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
    /// Retain a batch refused by the gateway.
    case proofRefused(statusCode: Int)
    case clientError(statusCode: Int)
    case retryLater(statusCode: Int, retryAfter: TimeInterval?)
    case serverError(statusCode: Int)
}

public protocol AnalyticsUploadOperationFactoryProtocol {
    func createUploadWrapper(body: Data, beforeSend: @escaping () throws -> Void) -> CompoundOperationWrapper<Void>
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
