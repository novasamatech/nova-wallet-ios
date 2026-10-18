import CryptoKit
import Foundation
import Operation_iOS

extension NovaAuth {
    func demand(
        context: NovaAuthContext,
        expectedClientID: String? = nil,
        intent: NovaAuthDemandIntent,
        cancellation: NovaAuthCancellation,
        completion: @escaping (Result<NovaAuthTokenRecord, Error>) -> Void
    ) {
        let waiterID = UUID()
        cancellation.install { [weak self] in self?.detach(waiterID: waiterID) }
        enqueue { [self] in
            var immediate: Result<NovaAuthTokenRecord, Error>?
            gate.novaAuthLocked {
                do {
                    try cancellation.check()
                    try validate(context: context)
                    try validateReadmission(clientID: expectedClientID)
                    guard isSupported else { throw NovaAuthError.unsupported }
                    let now = try dependencies.clock.now()
                    if let record = try usableToken(context: context, now: now) {
                        let remaining = try NovaAuthTokenValidation.remaining(
                            record,
                            context: context,
                            clientID: state?.identity?.clientID,
                            now: now
                        )
                        if remaining <= Double(record.earlyRefreshSeconds), flight == nil {
                            beginEarlyRefresh(context: context, now: now)
                        }
                        immediate = .success(record)
                    } else {
                        if let flight {
                            guard flight.context == context else { throw NovaAuthError.generationChanged }
                            flight.waiters[waiterID] = completion
                            return
                        }
                        try originCooldown.check(now: now)
                        try issuanceCooldown.check(now: now)
                        if case let .registrationPending(pending) = state?.identity?.registration {
                            try pending.cooldown.check(now: now)
                        }
                        if intent == .background, let refusal = state?.identity?.refusal {
                            try refusal.check(now: now, appVersion: dependencies.appIdentity.version)
                        }
                        try prepareIdentity(context: context)
                        let next = NovaAuthIssuanceFlight(context: context, sponsored: false)
                        next.waiters[waiterID] = completion
                        flight = next
                        start(flight: next)
                    }
                } catch { immediate = .failure(Self.safeError(error)) }
            }
            if let immediate, !cancellation.isCancelled { completion(immediate) }
        }
    }

    func usableToken(context: NovaAuthContext, now: NovaAuthTime) throws -> NovaAuthTokenRecord? {
        let record: NovaAuthTokenRecord?
        do {
            record = try dependencies.tokenStore.load()
        } catch { throw NovaAuthError.storageUnavailable }
        guard let record else { return nil }
        do { try rejectedCredentials.check(record, now: now) } catch { return nil }
        do {
            guard let clientID = state?.identity?.clientID else { throw NovaAuthError.credentialUnavailable }
            _ = try NovaAuthTokenValidation.remaining(record, context: context, clientID: clientID, now: now)
            return record
        } catch {
            try removeRejectedOrInvalidToken(record)
            return nil
        }
    }

    func issue(flight: NovaAuthIssuanceFlight) throws {
        guard let identity = state?.identity, let keyID = identity.keyID else { throw NovaAuthError.keyUnavailable }
        flight.step = .tokenChallenge
        guard !dependencies.appAttest.isBusy(keyID: keyID) else { throw NovaAuthAppAttestError.serverUnavailable }
        let wrapper = bootstrap.createTokenChallengeWrapper(
            origin: flight.context.origin,
            clientID: identity.clientID,
            beforeSend: { [self] in try beforeBootstrapSend(flight: flight, step: .tokenChallenge) }
        )
        run(wrapper, flight: flight) { [self] result in
            let challenge: NovaAuthChallenge
            do {
                challenge = try result.get()
            } catch {
                try handleBindingFailure(error, flight: flight)
                throw error
            }
            let preimage = try NovaAuthFraming.issuancePreimage(origin: flight.context.origin)
            let digest = Data(SHA256.hash(data: preimage))
            let hash = try NovaAuthFraming.clientDataHash(
                challenge: challenge.challenge,
                clientID: identity.clientID,
                origin: flight.context.origin,
                purpose: .token,
                contentType: "application/json",
                bodyDigest: digest
            )
            flight.irreversible = true
            flight.step = .assertion
            let assertionWrapper = dependencies.appAttest.createAssertionWrapper(keyID: keyID, clientDataHash: hash)
            run(assertionWrapper, flight: flight) { [self] result in
                guard let assertion = try assertion(from: result, flight: flight) else { return }
                let request = NovaAuthTokenRequest(
                    origin: flight.context.origin,
                    clientID: identity.clientID,
                    challenge: challenge.challenge,
                    assertion: assertion,
                    contentType: "application/json"
                )
                let tokenWrapper = bootstrap.createTokenWrapper(
                    request,
                    beforeSend: { [self] in try beforeBootstrapSend(flight: flight, step: .token) }
                )
                flight.step = .token
                run(tokenWrapper, flight: flight) { [self] result in
                    let response: NovaAuthTokenResponse
                    do {
                        response = try result.get()
                    } catch {
                        try handleBindingFailure(error, flight: flight)
                        throw error
                    }
                    guard let started = flight.issuanceStart else { throw NovaAuthError.clockUnavailable }
                    try install(response, started: started, clientID: identity.clientID, flight: flight)
                }
            }
        }
    }

    func install(
        _ response: NovaAuthTokenResponse,
        started: NovaAuthTime,
        clientID: String,
        flight: NovaAuthIssuanceFlight
    ) throws {
        try validate(context: flight.context)
        let lifetime = try NovaAuthValidation.lifetime(
            issuedAt: response.issuedAt, expiresAt: response.expiresAt, range: 60 ... 900
        )
        let random = dependencies.random.unitInterval()
        guard random.isFinite, (0 ... 1).contains(random) else { throw NovaAuthError.invalidResponse }
        let threshold = Int((Double(lifetime) * 0.20 + random * Double(lifetime) / 15).rounded())
        let record = NovaAuthTokenRecord(
            version: 2,
            context: flight.context,
            clientID: clientID,
            accessToken: response.accessToken,
            issuedAt: response.issuedAt,
            expiresAt: response.expiresAt,
            issuanceStart: started,
            earlyRefreshSeconds: threshold
        )
        _ = try NovaAuthTokenValidation.remaining(
            record, context: flight.context, clientID: clientID, now: dependencies.clock.now()
        )
        try setRegistration(.registered, flight: flight)
        do {
            try dependencies.tokenStore.replace(record)
        } catch { throw NovaAuthError.storageUnavailable }
        issuanceCooldown.clear()
        finish(.success(record), flight: flight)
    }

    func fail(_ error: Error, flight: NovaAuthIssuanceFlight) {
        guard self.flight === flight else { return }
        var safe = Self.safeError(error)
        if state?.context == flight.context {
            do {
                if shouldApplyCooldown(safe) {
                    let retryAfter: TimeInterval?
                    if case let NovaAuthError.bootstrap(server) = error, server.statusCode == 429 {
                        retryAfter = server.retryAfter ?? 30
                    } else { retryAfter = nil }
                    try failIssuanceCooldown(flight: flight, retryAfter: retryAfter)
                }
            } catch { safe = Self.safeError(error) }
        } else { safe = .generationChanged }
        NovaAuthDiagnostics.failure(safe, step: flight.step, logger: dependencies.logger)
        finish(.failure(safe), flight: flight)
    }

    static func safeError(_ error: Error) -> NovaAuthError {
        if let error = error as? NovaAuthError { return error }
        if let error = error as? URLError { return .transport(error.code) }
        if let error = error as? NovaAuthAppAttestError {
            switch error {
            case .invalidKey: return .keyUnavailable
            case .unsupported: return .unsupported
            case .serverUnavailable, .failure, .timedOut: return .platformUnavailable
            }
        }
        return .invalidResponse
    }
}

private extension NovaAuth {
    func validateReadmission(clientID: String?) throws {
        guard let clientID else { return }
        guard let identity = state?.identity, identity.clientID == clientID else {
            throw NovaAuthError.credentialUnavailable
        }
        if case .retired = identity.registration { throw NovaAuthError.keyUnavailable }
    }

    func assertion(from result: Result<Data, Error>, flight: NovaAuthIssuanceFlight) throws -> Data? {
        do { return try result.get() } catch NovaAuthAppAttestError.invalidKey {
            try retire(.lostKey, flight: flight)
            try createKey(flight: flight)
            return nil
        }
    }

    func shouldApplyCooldown(_ error: NovaAuthError) -> Bool {
        switch error {
        case .cancelled, .generationChanged, .cooldown: return false
        default: return true
        }
    }

    func beginEarlyRefresh(context: NovaAuthContext, now: NovaAuthTime) {
        do {
            guard case .registered = state?.identity?.registration else { return }
            try originCooldown.check(now: now)
            try issuanceCooldown.check(now: now)
            try prepareIdentity(context: context)
            let next = NovaAuthIssuanceFlight(context: context, sponsored: true)
            flight = next
            start(flight: next)
        } catch {}
    }

    func detach(waiterID: UUID) {
        gate.novaAuthLocked {
            guard let flight else { return }
            flight.waiters.removeValue(forKey: waiterID)
            if flight.waiters.isEmpty, !flight.sponsored, !flight.irreversible {
                self.flight = nil
                flight.cancelChild?()
            }
        }
    }
}
