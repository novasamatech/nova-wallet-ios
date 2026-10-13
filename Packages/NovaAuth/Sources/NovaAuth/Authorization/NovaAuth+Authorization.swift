import Foundation

extension NovaAuth: NovaAuthCredentialAuthority {
    var http: NovaAuthHTTPProtocol {
        dependencies.http
    }

    var requestQueue: OperationQueue {
        dependencies.requestQueue
    }

    func checkSend(request: NovaAuthRequest, record: NovaAuthTokenRecord) throws {
        try gate.novaAuthLocked {
            try validate(context: request.context)
            let now = try dependencies.clock.now()
            try originCooldown.check(now: now)
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
            guard case let .success(response) = result else { return }
            let status = response.response.statusCode
            let code = NovaAuthWire.errorCode(from: response.body)
            if status == 429 || (status == 503 && code == "attestation_unavailable") {
                originCooldown.fail(
                    now: now, random: dependencies.random.unitInterval(),
                    retryAfter: NovaAuthWire.retryAfter(response.response) ?? (status == 429 ? 30 : nil)
                )
            }
        }
    }

    func reject(record: NovaAuthTokenRecord, repeated: Bool, requestID _: String?) throws {
        try gate.novaAuthLocked {
            try validate(context: record.context)
            rejectedCredentials.reject(record)
            if repeated {
                let now = try dependencies.clock.now()
                issuanceCooldown.fail(now: now, random: dependencies.random.unitInterval())
            }
            try removeRejectedOrInvalidToken(record)
        }
    }

    func removeRejectedOrInvalidToken(_ record: NovaAuthTokenRecord) throws {
        do {
            let removed = try dependencies.tokenStore.remove(ifMatching: record)
            if !removed, try dependencies.tokenStore.load() == record {
                try dependencies.tokenStore.removeAll()
            }
        } catch { throw NovaAuthError.storageUnavailable }
    }
}
