import Foundation

enum BittensorApiError: Error {
    case unsupportedDevice
    case configuration
    case attestationRejected(requestId: String?)
    case attestationBackoff(until: Date?)
    case attestationUnavailable(requestId: String?)
    case attestationFailure(requestId: String?)
    case routeNotPublished
    case invalidRequest(code: String?, requestId: String?)
    case datasetUnavailable(requestId: String?)
    case rateLimited(requestId: String?)
    case upstreamUnavailable(requestId: String?)
    case upstreamInvalidResponse(requestId: String?)
    case server(statusCode: Int, code: String?, requestId: String?)
    case contractViolation(detail: String, requestId: String?)
    case transport(Error)
}
