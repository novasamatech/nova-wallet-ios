import Foundation
import Operation_iOS

struct BittensorApiCacheScope: Hashable {
    let origin: String
    let generation: UInt64
    let invalidationRevision: UInt64
}

struct BittensorApiAdmission {
    let scope: BittensorApiCacheScope
    let endpoint: NovaAuthEndpoint?
}

protocol BittensorApiTransportProtocol: AnyObject {
    var invalidationRevision: UInt64 { get }
    func createAdmissionWrapper() -> CompoundOperationWrapper<BittensorApiAdmission>
    func createResponseWrapper(
        for request: BittensorApiRequest,
        admission: BittensorApiAdmission
    ) -> CompoundOperationWrapper<BittensorApiRawResponse>
    func addInvalidationObserver(_ owner: AnyObject, closure: @escaping (UInt64) -> Void) -> UInt64
}
