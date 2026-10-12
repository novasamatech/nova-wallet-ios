import Foundation
import Operation_iOS
import NovaAuth

struct BittensorApiCacheScope: Hashable {
    let origin: String
    let profile: Int
    let generation: UInt64

    static let fixture = BittensorApiCacheScope(origin: "fixture", profile: 3, generation: 0)
}

struct BittensorApiAdmission {
    let scope: BittensorApiCacheScope
    let endpoint: NovaAuthEndpoint?
}

protocol BittensorApiTransportProtocol: AnyObject {
    func createResponseWrapper(for request: BittensorApiRequest) -> CompoundOperationWrapper<BittensorApiRawResponse>
}

protocol BittensorApiAdmittingTransportProtocol: BittensorApiTransportProtocol {
    func createAdmissionWrapper(intent: NovaAuthRequestIntent) -> CompoundOperationWrapper<BittensorApiAdmission>
    func createResponseWrapper(
        for request: BittensorApiRequest,
        admission: BittensorApiAdmission
    ) -> CompoundOperationWrapper<BittensorApiRawResponse>
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void)
}

extension BittensorApiTransportProtocol {
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void) {
        (self as? BittensorApiAdmittingTransportProtocol)?.addContextObserver(owner, closure: closure)
    }

    func createAdmissionWrapper(intent: NovaAuthRequestIntent) -> CompoundOperationWrapper<BittensorApiAdmission> {
        (self as? BittensorApiAdmittingTransportProtocol)?.createAdmissionWrapper(intent: intent)
            ?? .createWithResult(BittensorApiAdmission(scope: .fixture, endpoint: nil))
    }

    func createResponseWrapper(
        for request: BittensorApiRequest,
        admission: BittensorApiAdmission
    ) -> CompoundOperationWrapper<BittensorApiRawResponse> {
        (self as? BittensorApiAdmittingTransportProtocol)?.createResponseWrapper(for: request, admission: admission)
            ?? createResponseWrapper(for: request)
    }
}
