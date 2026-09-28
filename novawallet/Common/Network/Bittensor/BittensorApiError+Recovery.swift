import Foundation

extension BittensorApiError {
    var isDeviceBound: Bool {
        switch self {
        case .unsupportedDevice, .attestationRejected, .attestationBackoff, .attestationFailure, .configuration,
             .invalidRequest:
            return true
        case .routeNotPublished, .datasetUnavailable, .rateLimited, .upstreamUnavailable, .upstreamInvalidResponse,
             .attestationUnavailable, .server, .contractViolation, .transport:
            return false
        }
    }
}
