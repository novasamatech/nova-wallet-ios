import Foundation

enum BittensorApiError: Error {
    case deviceBound(requestId: String?)
    case rejected(code: String?, requestId: String?)
    case unavailable(code: String?, requestId: String?)
    case generationStale
    case contractViolation(detail: String, requestId: String?)
    case transport(Error)

    var isDeviceBound: Bool {
        if case .deviceBound = self { return true }
        return false
    }

    var allowsUserRetry: Bool {
        switch self {
        case .deviceBound, .rejected:
            return false
        case .unavailable, .generationStale, .contractViolation, .transport:
            return true
        }
    }
}
