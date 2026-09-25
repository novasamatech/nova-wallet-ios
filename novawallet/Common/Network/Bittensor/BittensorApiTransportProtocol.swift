import Foundation
import Operation_iOS

protocol BittensorApiTransportProtocol: AnyObject {
    func createResponseWrapper(for request: BittensorApiRequest) -> CompoundOperationWrapper<BittensorApiRawResponse>
}
