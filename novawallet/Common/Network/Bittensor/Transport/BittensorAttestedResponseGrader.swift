import Foundation
import NovaAppAttest

struct BittensorAttestedResponse {
    let statusCode: Int
    let contentType: String?
    let requestId: String?
    let body: Data
}

enum BittensorAttestedGrade {
    case success(BittensorApiRawResponse)
    case retryWithFreshProof(requestId: String?)
    case unknownClient(requestId: String?)
    case failure(BittensorApiError)
}

enum BittensorAttestedResponseGrader {
    static func grade(
        _ response: BittensorAttestedResponse,
        isRecommendationsRoute: Bool
    ) -> BittensorAttestedGrade {
        let code = AttestationHTTP.rawErrorCode(from: response.body)
        let requestId = response.requestId

        switch response.statusCode {
        case 200 ..< 300:
            return .success(
                BittensorApiRawResponse(statusCode: response.statusCode, requestId: requestId, body: response.body)
            )
        case 401:
            return gradeUnauthorized(code: code, requestId: requestId)
        case 403:
            return .failure(gradeForbidden(code: code, requestId: requestId))
        case 404:
            return .failure(gradeNotFound(response, code: code))
        case 400:
            return .failure(
                gradeBadRequest(code: code, requestId: requestId, isRecommendationsRoute: isRecommendationsRoute)
            )
        case 405, 413, 415:
            return .failure(.invalidRequest(code: code, requestId: requestId))
        case 500 ... 599:
            return .failure(gradeServerError(statusCode: response.statusCode, code: code, requestId: requestId))
        default:
            return .failure(.server(statusCode: response.statusCode, code: code, requestId: requestId))
        }
    }

    static func mapSigningError(_ error: Error) -> BittensorApiError {
        if let apiError = error as? BittensorApiError {
            return apiError
        }

        if let attestationError = error as? BackendAttestationError {
            return mapAttestationError(attestationError)
        }

        if let appAttestError = error as? AppAttestServiceError, case .serviceUnavailable = appAttestError {
            return .attestationUnavailable(requestId: nil)
        }

        if error is URLError {
            return .transport(error)
        }

        return .attestationFailure(requestId: nil)
    }

    static func carryingRequestId(_ requestId: String?, in error: BittensorApiError) -> BittensorApiError {
        switch error {
        case let .attestationRejected(currentId):
            return .attestationRejected(requestId: currentId ?? requestId)
        case let .attestationUnavailable(currentId):
            return .attestationUnavailable(requestId: currentId ?? requestId)
        case let .attestationFailure(currentId):
            return .attestationFailure(requestId: currentId ?? requestId)
        case let .rateLimited(currentId):
            return .rateLimited(requestId: currentId ?? requestId)
        default:
            return error
        }
    }

    static func isChallengeRateLimit(_ error: Error) -> Bool {
        guard
            let attestationError = error as? BackendAttestationError,
            case let .clientError(statusCode) = attestationError else {
            return false
        }

        return statusCode == Constants.tooManyRequests
    }
}

private extension BittensorAttestedResponseGrader {
    enum Constants {
        static let tooManyRequests = 429
        static let plainTextContentType = "text/plain"
        static let cloudflareStatuses = 520 ... 527
    }

    enum ErrorCode {
        static let invalidChallenge = "invalid_challenge"
        static let invalidProof = "invalid_proof"
        static let unknownClient = "unknown_client"
        static let bindingNotAllowed = "binding_not_allowed"
        static let appNotAllowed = "app_not_allowed"
        static let invalidTarget = "invalid_target"
        static let routeNotFound = "route_not_found"
        static let attestationUnavailable = "attestation_unavailable"
        static let upstreamUnavailable = "upstream_unavailable"
        static let upstreamInvalidResponse = "upstream_invalid_response"
        static let datasetUnavailable = "dataset_unavailable"
        static let rateLimited = "rate_limited"
    }

    static func mapAttestationError(_ error: BackendAttestationError) -> BittensorApiError {
        switch error {
        case .unsupported:
            return .configuration
        case let .retryLater(until):
            return .attestationBackoff(until: until)
        case .rejected:
            return .attestationRejected(requestId: nil)
        case let .clientError(statusCode) where statusCode == Constants.tooManyRequests:
            return .rateLimited(requestId: nil)
        case .serverError:
            return .attestationUnavailable(requestId: nil)
        case .unauthorized, .clientError, .invalidResponse:
            return .attestationFailure(requestId: nil)
        }
    }

    static func gradeUnauthorized(code: String?, requestId: String?) -> BittensorAttestedGrade {
        switch code {
        case ErrorCode.invalidChallenge, ErrorCode.invalidProof:
            return .retryWithFreshProof(requestId: requestId)
        case ErrorCode.unknownClient:
            return .unknownClient(requestId: requestId)
        default:
            return .failure(.server(statusCode: 401, code: code, requestId: requestId))
        }
    }

    static func gradeForbidden(code: String?, requestId: String?) -> BittensorApiError {
        switch code {
        case ErrorCode.bindingNotAllowed, ErrorCode.appNotAllowed:
            return .attestationRejected(requestId: requestId)
        default:
            return .server(statusCode: 403, code: code, requestId: requestId)
        }
    }

    static func gradeNotFound(_ response: BittensorAttestedResponse, code: String?) -> BittensorApiError {
        let isPlainText = response.contentType?.lowercased().hasPrefix(Constants.plainTextContentType) ?? false

        if isPlainText {
            return .routeNotPublished
        }

        if code == ErrorCode.routeNotFound {
            return .invalidRequest(code: code, requestId: response.requestId)
        }

        return .server(statusCode: response.statusCode, code: code, requestId: response.requestId)
    }

    static func gradeBadRequest(
        code: String?,
        requestId: String?,
        isRecommendationsRoute: Bool
    ) -> BittensorApiError {
        if isRecommendationsRoute, code == ErrorCode.invalidTarget {
            return .routeNotPublished
        }

        return .invalidRequest(code: code, requestId: requestId)
    }

    static func gradeServerError(statusCode: Int, code: String?, requestId: String?) -> BittensorApiError {
        if Constants.cloudflareStatuses.contains(statusCode) {
            return .attestationUnavailable(requestId: requestId)
        }

        switch code {
        case nil, ErrorCode.attestationUnavailable:
            return .attestationUnavailable(requestId: requestId)
        case ErrorCode.upstreamUnavailable where statusCode == 502:
            return .upstreamUnavailable(requestId: requestId)
        case ErrorCode.upstreamInvalidResponse where statusCode == 502:
            return .upstreamInvalidResponse(requestId: requestId)
        case ErrorCode.datasetUnavailable where statusCode == 503:
            return .datasetUnavailable(requestId: requestId)
        case ErrorCode.rateLimited where statusCode == 503:
            return .rateLimited(requestId: requestId)
        default:
            return .server(statusCode: statusCode, code: code, requestId: requestId)
        }
    }
}
