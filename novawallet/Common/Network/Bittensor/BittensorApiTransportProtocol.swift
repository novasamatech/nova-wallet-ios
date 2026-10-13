import Foundation
import Operation_iOS
import NovaAuth

struct BittensorApiCacheScope: Hashable {
    let origin: String
    let profile: Int
    let generation: UInt64
    let invalidationRevision: UInt64

    static let fixture = BittensorApiCacheScope(
        origin: "fixture", profile: 3, generation: 0, invalidationRevision: 0
    )
}

struct BittensorApiAdmission {
    let scope: BittensorApiCacheScope
    let endpoint: NovaAuthEndpoint?
}

protocol BittensorApiTransportProtocol: AnyObject {
    func createResponseWrapper(for request: BittensorApiRequest) -> CompoundOperationWrapper<BittensorApiRawResponse>
}

protocol BittensorApiAdmittingTransportProtocol: BittensorApiTransportProtocol {
    var invalidationRevision: UInt64 { get }
    func createAdmissionWrapper(intent: NovaAuthRequestIntent) -> CompoundOperationWrapper<BittensorApiAdmission>
    func createResponseWrapper(
        for request: BittensorApiRequest,
        admission: BittensorApiAdmission
    ) -> CompoundOperationWrapper<BittensorApiRawResponse>
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void)
    func addInvalidationObserver(_ owner: AnyObject, closure: @escaping (UInt64) -> Void) -> UInt64
}

extension BittensorApiTransportProtocol {
    var invalidationRevision: UInt64 {
        (self as? BittensorApiAdmittingTransportProtocol)?.invalidationRevision ?? 0
    }

    func addInvalidationObserver(_ owner: AnyObject, closure: @escaping (UInt64) -> Void) -> UInt64 {
        (self as? BittensorApiAdmittingTransportProtocol)?.addInvalidationObserver(owner, closure: closure) ?? 0
    }

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
