import Foundation
import NovaAuth

enum BittensorAuthorizedRequestBuilder {
    static func prepare(_ request: BittensorApiRequest, endpoint: NovaAuthEndpoint) throws -> NovaAuthRequest {
        let root = "/v1/bittensor"
        return try NovaAuthRequest(
            context: endpoint.context,
            method: .get,
            path: root + request.path,
            queryItems: request.queryItems,
            body: nil,
            contentType: nil
        )
    }
}
