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

public protocol AnalyticsAuthProvidingProtocol: AnyObject {
    func createAuthWrapper() -> CompoundOperationWrapper<AnalyticsAuth>
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void)
}

public extension AnalyticsAuthProvidingProtocol {
    func addContextObserver(_: AnyObject, closure _: @escaping () -> Void) {}
}
