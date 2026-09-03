import Foundation
import Operation_iOS

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

    /// Created on first call, never before.
    func installId() -> String
    func forgetInstallId()
}

protocol AnalyticsAvailabilityProviderProtocol: AnyObject {
    var isAvailable: Bool { get }
}

/// Declared here until the attestation seams land; it then moves to
/// `Common/Services/Attestation/BackendAttestationProtocols.swift` unchanged.
enum BackendAttestationMode {
    case appAttest
    case none
    case unavailable
}
