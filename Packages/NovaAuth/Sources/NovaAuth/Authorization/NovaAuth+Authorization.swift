import Foundation

extension NovaAuth: NovaAuthCredentialAuthority {
    var http: NovaAuthHTTPProtocol { dependencies.http }
    var requestQueue: OperationQueue { dependencies.requestQueue }

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

    func receive(_ result: Result<NovaAuthResponse, Error>, context: NovaAuthContext) throws {
        try gate.novaAuthLocked {
            try validate(context: context)
            let now = try dependencies.clock.now()
            switch result {
            case let .success(response):
                switch response.response.statusCode {
                case 429:
                    originCooldown.fail(
                        now: now,
                        random: dependencies.random.unitInterval(),
                        retryAfter: NovaAuthWire.retryAfter(response.response) ?? 30
                    )
                case 503:
                    originCooldown.fail(now: now, random: dependencies.random.unitInterval())
                case 200 ..< 400:
                    originCooldown.succeed(now: now)
                default: break
                }
            case let .failure(error):
                let safe = Self.safeError(error)
                if case .transport = safe {
                    originCooldown.fail(now: now, random: dependencies.random.unitInterval())
                }
            }
        }
    }

    func reject(record: NovaAuthTokenRecord, repeated: Bool, requestID _: String?) throws {
        try gate.novaAuthLocked {
            try validate(context: record.context)
            rejectedCredentials.reject(record)
            do {
                try dependencies.tokenStore.remove(ifMatching: record)
            } catch { throw NovaAuthError.storageUnavailable }
            if repeated {
                issuanceCooldown.fail(now: try dependencies.clock.now(), random: dependencies.random.unitInterval())
            }
        }
    }
}
