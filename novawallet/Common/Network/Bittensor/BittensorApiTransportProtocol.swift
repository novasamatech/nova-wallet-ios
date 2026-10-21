import Foundation
import Operation_iOS

struct BittensorApiCacheScope: Hashable {
    let origin: String
    let generation: UInt64
}

struct BittensorApiAdmission {
    let scope: BittensorApiCacheScope
    let endpoint: NovaAuthEndpoint
}

protocol BittensorApiTransportProtocol: AnyObject {
    func createAdmissionWrapper() -> CompoundOperationWrapper<BittensorApiAdmission>
    func createResponseWrapper(
        for request: BittensorApiRequest,
        admission: BittensorApiAdmission
    ) -> CompoundOperationWrapper<BittensorApiRawResponse>
}
