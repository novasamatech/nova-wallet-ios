import Foundation
import Operation_iOS
import NovaAuth

public struct AnalyticsAuth {
    public let context: NovaAuthContext
    public let client: NovaAuthClientProtocol

    public init(context: NovaAuthContext, client: NovaAuthClientProtocol) {
        self.context = context
        self.client = client
    }
}

public struct AnalyticsAuthAvailability {
    public let revision: UInt64
    public let invalidationRevision: UInt64
    public let auth: AnalyticsAuth?

    public init(revision: UInt64 = 0, invalidationRevision: UInt64 = 0, auth: AnalyticsAuth? = nil) {
        self.revision = revision
        self.invalidationRevision = invalidationRevision
        self.auth = auth
    }
}

public protocol AnalyticsAuthProvidingProtocol: AnyObject {
    var authAvailability: AnalyticsAuthAvailability { get }
    func createAuthWrapper() -> CompoundOperationWrapper<AnalyticsAuth>
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void)
    func addAvailabilityObserver(
        _ owner: AnyObject,
        closure: @escaping (AnalyticsAuthAvailability) -> Void
    ) -> AnalyticsAuthAvailability
}

public extension AnalyticsAuthProvidingProtocol {
    var authAvailability: AnalyticsAuthAvailability { AnalyticsAuthAvailability() }
    func addContextObserver(_: AnyObject, closure _: @escaping () -> Void) {}
    func addAvailabilityObserver(
        _: AnyObject,
        closure _: @escaping (AnalyticsAuthAvailability) -> Void
    ) -> AnalyticsAuthAvailability { authAvailability }
}
