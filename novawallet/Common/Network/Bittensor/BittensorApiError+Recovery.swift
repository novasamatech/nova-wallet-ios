import Foundation

extension BittensorApiError {
    var isDeviceBound: Bool {
        switch self {
        case .unsupportedDevice, .attestationRejected, .attestationBackoff, .attestationFailure, .configuration:
            return true
        case .bindingConflict, .invalidRequest, .generationStale, .routeNotPublished, .datasetUnavailable, .rateLimited,
             .upstreamUnavailable, .upstreamInvalidResponse,
             .attestationUnavailable, .server, .contractViolation, .transport:
            return false
        }
    }

    var allowsUserRetry: Bool {
        switch self {
        case .unsupportedDevice, .configuration, .attestationRejected, .bindingConflict,
             .attestationBackoff, .attestationFailure, .invalidRequest:
            return false
        case .generationStale, .routeNotPublished, .datasetUnavailable, .rateLimited,
             .upstreamUnavailable, .upstreamInvalidResponse,
             .attestationUnavailable, .server, .contractViolation, .transport:
            return true
        }
    }
}
