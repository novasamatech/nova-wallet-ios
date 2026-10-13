import Foundation
import SDKLogger

enum NovaAuthDiagnostics {
    private static let queue = DispatchQueue(label: "io.novawallet.novaauth.diagnostics")
    enum Event: String {
        case registrationStarted, registrationPending, identityRecovered
        case policyRefused, tokenInstalled, contextReplaced, storageFailed, storageRecovery
        case bearerRejected, bearerDeniedRepeated, bearerRecovered
    }

    enum CooldownScope: String {
        case shared, family, recreation, policy, proof
    }

    enum CooldownDelay {
        case bounded(TimeInterval)
        case localRecovery(TimeInterval)
    }

    enum Phase: String {
        case registrationChallenge, keyGeneration, attestation, registration, tokenChallenge, assertion, token
    }

    static func failure(_ error: NovaAuthError, phase: Phase, logger: SDKLoggerProtocol?) {
        let reason: String
        var status: Int?
        var requestID: String?
        var delay: TimeInterval?
        switch error {
        case .unsupported: reason = "unsupported"
        case .invalidConfiguration: reason = "configuration"
        case .invalidRequest: reason = "request"
        case .invalidResponse: reason = "response"
        case .credentialUnavailable: reason = "credential"
        case .generationChanged: reason = "generation"
        case .userActionRequired: reason = "userAction"
        case .storageUnavailable: reason = "storage"
        case .clockUnavailable: reason = "clock"
        case .keyUnavailable: reason = "key"
        case .platformUnavailable: reason = "platform"
        case let .authorizationDenied(identifier): reason = "denied"; requestID = identifier
        case let .cooldown(seconds): reason = "cooldown"; delay = seconds
        case let .bootstrap(server):
            reason = "bootstrap"
            if (100 ... 599).contains(server.statusCode) { status = server.statusCode }
            requestID = server.requestID
            delay = server.retryAfter
        case .transport: reason = "transport"
        case .cancelled: reason = "cancelled"
        }
        var message = "NovaAuth failure phase=\(phase.rawValue) reason=\(reason)"
        if let status { message += " status=\(status)" }
        message += metadata(requestID: requestID, retryAfter: delay)
        let safeMessage = message
        queue.async { logger?.warning(safeMessage) }
    }

    static func log(_ event: Event, logger: SDKLoggerProtocol?, requestID: String? = nil) {
        let message = "NovaAuth transition=\(event.rawValue)" + metadata(requestID: requestID, retryAfter: nil)
        queue.async {
            switch event {
            case .policyRefused, .storageFailed, .storageRecovery, .bearerDeniedRepeated:
                logger?.warning(message)
            default:
                logger?.info(message)
            }
        }
    }

    static func retired(_ reason: NovaAuthRetirementReason, logger: SDKLoggerProtocol?) {
        let message = "NovaAuth transition=identityRetired reason=\(reason.rawValue)"
        queue.async { logger?.warning(message) }
    }

    static func cooldown(scope: CooldownScope, delay: CooldownDelay?, logger: SDKLoggerProtocol?) {
        var message = "NovaAuth transition=cooldown scope=\(scope.rawValue)"
        switch delay {
        case let .bounded(seconds):
            message += metadata(requestID: nil, retryAfter: seconds)
        case let .localRecovery(seconds):
            let maximum: TimeInterval = 95040
            let roundingTolerance: TimeInterval = 0.000001
            if seconds.isFinite, seconds >= 0, seconds <= maximum + roundingTolerance {
                message += " retryAfter=\(Int(min(seconds, maximum).rounded(.up)))"
            }
        case nil: break
        }
        let safeMessage = message
        queue.async { logger?.info(safeMessage) }
    }

    private static func metadata(requestID: String?, retryAfter: TimeInterval?) -> String {
        var message = ""
        if let requestID, (1 ... 128).contains(requestID.utf8.count), requestID.utf8.allSatisfy({
            (65 ... 90).contains($0) || (97 ... 122).contains($0) || (48 ... 57).contains($0) ||
                [46, 95, 58, 45].contains($0)
        }) { message += " requestID=\(requestID)" }
        if let retryAfter, retryAfter.isFinite, (0 ... 905).contains(retryAfter) {
            message += " retryAfter=\(Int(retryAfter.rounded(.up)))"
        }
        return message
    }
}
