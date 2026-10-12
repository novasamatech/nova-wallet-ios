import Foundation

extension NovaAuth: NovaAuthCredentialAuthority {
    var http: NovaAuthHTTPProtocol { dependencies.http }
    var requestQueue: OperationQueue { dependencies.requestQueue }

    func checkSend(request: NovaAuthRequest, record: NovaAuthTokenRecord) throws {
        try gate.novaAuthLocked {
            try validate(context: request.context)
            let now = try dependencies.clock.now()
            try originCooldown.check(now: now)
            try businessCooldowns.check(request: request, now: now)
            guard try usableToken(context: request.context, now: now) != nil else {
                throw NovaAuthError.credentialUnavailable
            }
            _ = try NovaAuthTokenValidation.remaining(
                record,
                context: request.context,
                clientID: state?.identity?.clientID,
                now: now
            )
            try rejectedCredentials.check(record, now: now)
        }
    }

    func receive(_ result: Result<NovaAuthResponse, Error>, request: NovaAuthRequest) throws {
        try gate.novaAuthLocked {
            try validate(context: request.context)
            let now = try dependencies.clock.now()
            let applied = businessCooldowns.receive(
                result, request: request, now: now,
                random: dependencies.random.unitInterval(), origin: &originCooldown
            )
            if let applied {
                NovaAuthDiagnostics.cooldown(
                    scope: applied.scope, delay: .bounded(applied.retryAfter), logger: dependencies.logger
                )
            }
        }
    }

    func reject(record: NovaAuthTokenRecord, repeated: Bool, requestID: String?) throws {
        try gate.novaAuthLocked {
            try validate(context: record.context)
            rejectedCredentials.reject(record)
            NovaAuthDiagnostics.log(
                repeated ? .bearerDeniedRepeated : .bearerRejected,
                logger: dependencies.logger, requestID: requestID
            )
            if repeated {
                let now = try dependencies.clock.now()
                issuanceCooldown.fail(now: now, random: dependencies.random.unitInterval())
                NovaAuthDiagnostics.cooldown(
                    scope: .shared,
                    delay: issuanceCooldown.deadline.map { .bounded(max(0, $0.continuousSeconds - now.continuousSeconds)) },
                    logger: dependencies.logger
                )
            }
            try removeRejectedOrInvalidToken(record)
        }
    }

    // The sole writer holds its gate across this fallback for an untagged legacy record.
    func removeRejectedOrInvalidToken(_ record: NovaAuthTokenRecord) throws {
        do {
            let removed = try dependencies.tokenStore.remove(ifMatching: record)
            if !removed, try dependencies.tokenStore.load() == record {
                try dependencies.tokenStore.removeAll()
            }
        } catch { throw NovaAuthError.storageUnavailable }
    }

    func recovered(requestID: String?) {
        NovaAuthDiagnostics.log(.bearerRecovered, logger: dependencies.logger, requestID: requestID)
    }
}
