import Foundation
import NovaAuth

enum BittensorAuthorizedRequestBuilder {
    static func prepare(_ request: BittensorApiRequest, endpoint: NovaAuthEndpoint) throws -> NovaAuthRequest {
        let method: NovaAuthMethod
        switch request.method {
        case .get: method = .get
        case .post: method = .post
        }
        let root = request.method == .post ? "/v1/bittensor" : "/v1/bittensor/profile-3"
        return try NovaAuthRequest(
            context: endpoint.context,
            method: method,
            path: root + request.path,
            queryItems: request.queryItems,
            body: request.jsonBody,
            contentType: request.method == .post ? "application/json" : nil,
            intent: request.intent
        )
    }
}
