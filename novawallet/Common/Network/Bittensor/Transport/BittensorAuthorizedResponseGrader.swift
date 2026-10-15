import Foundation
import NovaAuth

enum BittensorAuthorizedResponseGrader {
    static func grade(_ result: NovaAuthResponse) throws -> BittensorApiRawResponse {
        let response = result.response
        let status = response.statusCode
        let requestId = bounded(response.value(forHTTPHeaderField: "X-Request-ID"))
        if (200 ..< 300).contains(status) {
            return BittensorApiRawResponse(
                statusCode: status, requestId: requestId, body: result.body,
                directives: HTTPCacheDirectives(response: response)
            )
        }
        let code = errorCode(result.body)
        let isRejected: Bool
        switch status {
        case 400, 405, 413, 415, 422:
            isRejected = true
        case 403:
            isRejected = code == "insufficient_scope"
        case 404:
            let isPlainText = response.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("text/plain")
            isRejected = code == "route_not_found" && isPlainText != true
        case 409:
            isRejected = code == "client_already_registered"
        default:
            isRejected = false
        }
        throw isRejected
            ? BittensorApiError.rejected(code: code, requestId: requestId)
            : BittensorApiError.unavailable(code: code, requestId: requestId)
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

    private static func errorCode(_ data: Data) -> String? {
        guard data.count <= 8192,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any], let code = error["code"] as? String,
              code.utf8.count <= 64, code.utf8.allSatisfy({ (97 ... 122).contains($0) || $0 == 95 }) else { return nil }
        return code
    }

    private static func bounded(_ value: String?) -> String? {
        guard let value, (1 ... 128).contains(value.utf8.count),
              value.utf8.allSatisfy({ (33 ... 126).contains($0) }) else { return nil }
        return value
    }
}
