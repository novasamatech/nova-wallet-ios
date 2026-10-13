import Foundation
import NovaAuth
import Operation_iOS

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
}
