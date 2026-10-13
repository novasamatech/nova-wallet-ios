import Foundation
import NovaAuth

enum BittensorAuthorizedResponseGrader {
    static func grade(_ result: NovaAuthResponse) throws -> BittensorApiRawResponse {
        let response = result.response
        let status = response.statusCode
        let requestId = bounded(response.value(forHTTPHeaderField: "X-Request-ID"))
        if (200 ..< 300).contains(status) {
            return BittensorApiRawResponse(
                statusCode: status,
                requestId: requestId,
                body: result.body,
                cacheDirectives: HTTPCacheDirectives(response: response)
            )
        }
        let code = errorCode(result.body)
        switch status {
        case 409 where code == "client_already_registered":
            throw BittensorApiError.bindingConflict(requestId: requestId)
        case 403 where code == "insufficient_scope":
            throw BittensorApiError.invalidRequest(code: code, requestId: requestId)
        case 401, 403:
            throw BittensorApiError.server(statusCode: status, code: code, requestId: requestId)
        case 404 where response.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("text/plain") == true:
            throw BittensorApiError.routeNotPublished
        case 400, 405, 413, 415, 422:
            throw BittensorApiError.invalidRequest(code: code, requestId: requestId)
        case 404 where code == "route_not_found":
            throw BittensorApiError.invalidRequest(code: code, requestId: requestId)
        case 429:
            throw BittensorApiError.rateLimited(requestId: requestId)
        case 502 where code == "upstream_unavailable":
            throw BittensorApiError.upstreamUnavailable(requestId: requestId)
        case 502 where code == "upstream_invalid_response":
            throw BittensorApiError.upstreamInvalidResponse(requestId: requestId)
        case 503 where code == "dataset_unavailable":
            throw BittensorApiError.datasetUnavailable(requestId: requestId)
        case 503 where code == "rate_limited":
            throw BittensorApiError.rateLimited(requestId: requestId)
        case 500 ... 599 where code == nil:
            throw BittensorApiError.attestationUnavailable(requestId: requestId)
        default:
            throw BittensorApiError.server(statusCode: status, code: code, requestId: requestId)
        }
    }

    static func map(_ error: Error) -> BittensorApiError {
        if let error = error as? BittensorApiError { return error }
        if let error = error as? URLError { return .transport(error) }
        guard let error = error as? NovaAuthError else { return .attestationUnavailable(requestId: nil) }
        switch error {
        case .unsupported: return .unsupportedDevice
        case .invalidConfiguration: return .configuration
        case let .authorizationDenied(requestID): return .attestationFailure(requestId: requestID)
        case .cooldown: return .rateLimited(requestId: nil)
        case let .bootstrap(server):
            if server.statusCode == 429 { return .rateLimited(requestId: server.requestID) }
            if server.statusCode == 409, server.code == "client_already_registered" {
                return .bindingConflict(requestId: server.requestID)
            }
            if server.statusCode == 401, server.code == "attestation_failed" {
                return .attestationRejected(requestId: server.requestID)
            }
            if server.statusCode == 403, server.code == "insufficient_scope" {
                return .invalidRequest(code: server.code, requestId: server.requestID)
            }
            if server.statusCode == 403, server.code == "app_not_allowed" || server.code == "binding_not_allowed" {
                return .attestationRejected(requestId: server.requestID)
            }
            return .attestationUnavailable(requestId: server.requestID)
        case let .transport(code): return .transport(URLError(code))
        case .generationChanged: return .generationStale
        case .credentialUnavailable, .storageUnavailable,
             .clockUnavailable, .keyUnavailable, .platformUnavailable:
            return .attestationUnavailable(requestId: nil)
        case .invalidRequest: return .invalidRequest(code: nil, requestId: nil)
        case .invalidResponse: return .attestationUnavailable(requestId: nil)
        case .cancelled: return .transport(URLError(.cancelled))
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
