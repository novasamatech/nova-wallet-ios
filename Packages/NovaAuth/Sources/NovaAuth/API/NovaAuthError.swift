import Foundation

public struct NovaAuthServerError: Error, Equatable {
    public let statusCode: Int
    public let code: String?
    public let requestID: String?
    public let retryAfter: TimeInterval?

    public init(statusCode: Int, code: String?, requestID: String?, retryAfter: TimeInterval?) {
        self.statusCode = statusCode
        self.code = code
        self.requestID = requestID
        self.retryAfter = retryAfter
    }
}

public enum NovaAuthError: Error, Equatable {
    case unsupported
    case invalidConfiguration
    case invalidRequest
    case invalidResponse
    case credentialUnavailable
    case generationChanged
    case storageUnavailable
    case clockUnavailable
    case keyUnavailable
    case platformUnavailable
    case authorizationDenied(requestID: String?)
    case cooldown(retryAfter: TimeInterval)
    case bootstrap(NovaAuthServerError)
    case transport(URLError.Code)
    case cancelled
}
