import Foundation
import NovaAuth

enum BittensorAuthorizedResponseGrader {
    static func grade(_ result: NovaAuthResponse) throws -> BittensorApiRawResponse {
        let status = result.response.statusCode
        if (200 ..< 300).contains(status) {
            return BittensorApiRawResponse(
                requestId: result.requestID,
                body: result.body,
                directives: HTTPCacheDirectives(response: result.response)
            )
        }
        let server = result.serverError
        let isRejected: Bool
        switch status {
        case 400, 405, 413, 415, 422:
            isRejected = true
        case 403:
            isRejected = server.code == "insufficient_scope"
        case 404:
            isRejected = server.code == "route_not_found"
        case 409:
            isRejected = server.code == "client_already_registered"
        default:
            isRejected = false
        }
        throw isRejected
            ? BittensorApiError.rejected(code: server.code, requestId: server.requestID)
            : BittensorApiError.unavailable(code: server.code, requestId: server.requestID)
    }

    static func map(_ error: Error) -> BittensorApiError {
        if let error = error as? BittensorApiError { return error }
        if let error = error as? URLError { return .transport(error) }
        guard let error = error as? NovaAuthError else { return .unavailable(code: nil, requestId: nil) }
        switch error {
        case .unsupported, .invalidConfiguration:
            return .deviceBound(requestId: nil)
        case let .authorizationDenied(requestID):
            return .deviceBound(requestId: requestID)
        case let .bootstrap(server):
            switch (server.statusCode, server.code) {
            case (409, "client_already_registered"?), (403, "insufficient_scope"?):
                return .rejected(code: server.code, requestId: server.requestID)
            case (401, "attestation_failed"?), (403, "app_not_allowed"?), (403, "binding_not_allowed"?):
                return .deviceBound(requestId: server.requestID)
            default:
                return .unavailable(code: server.code, requestId: server.requestID)
            }
        case let .transport(code):
            return .transport(URLError(code))
        case .generationChanged:
            return .generationStale
        case .invalidRequest:
            return .rejected(code: nil, requestId: nil)
        case .cooldown, .credentialUnavailable, .storageUnavailable, .clockUnavailable, .keyUnavailable,
             .platformUnavailable, .invalidResponse:
            return .unavailable(code: nil, requestId: nil)
        case .cancelled:
            return .transport(URLError(.cancelled))
        }
    }
}
