import Foundation
import SDKLogger

enum NovaAuthDiagnostics {
    private static let queue = DispatchQueue(label: "novaauth.diagnostics")

    static func failure(_ error: NovaAuthError, step: BootstrapStep, logger: SDKLoggerProtocol?) {
        let category: String
        var server: NovaAuthServerError?
        var requestID: String?
        switch error {
        case .unsupported: category = "unsupported"
        case .invalidConfiguration: category = "configuration"
        case .invalidRequest: category = "request"
        case .invalidResponse: category = "response"
        case .credentialUnavailable: category = "credential"
        case .generationChanged: category = "generation"
        case .storageUnavailable: category = "storage"
        case .clockUnavailable: category = "clock"
        case .keyUnavailable: category = "key"
        case .platformUnavailable: category = "platform"
        case let .authorizationDenied(identifier): category = "denied"; requestID = identifier
        case .cooldown: category = "cooldown"
        case let .bootstrap(value): category = "bootstrap"; server = value; requestID = value.requestID
        case .transport: category = "transport"
        case .cancelled: category = "cancelled"
        }
        var message = "NovaAuth failure step=\(step.rawValue) category=\(category)"
        if let server, (100 ... 599).contains(server.statusCode) {
            message += " status=\(server.statusCode)"
            if let code = server.code, [
                "unknown_client", "invalid_proof", "binding_not_allowed", "app_not_allowed", "attestation_failed",
                "attestation_unavailable", "invalid_token", "client_conflict"
            ].contains(code) { message += " code=\(code)" }
        }
        if let requestID, (1 ... 128).contains(requestID.utf8.count), requestID.utf8.allSatisfy({
            (65 ... 90).contains($0) || (97 ... 122).contains($0) || (48 ... 57).contains($0) ||
                [46, 95, 58, 45].contains($0)
        }) { message += " requestID=\(requestID)" }
        let redacted = message
        queue.async { logger?.warning(redacted) }
    }
}
