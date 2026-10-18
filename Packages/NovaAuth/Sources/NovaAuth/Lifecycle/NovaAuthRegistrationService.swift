import CryptoKit
import Foundation

extension NovaAuth {
    func prepareIdentity(context: NovaAuthContext) throws {
        guard let state else { throw NovaAuthError.generationChanged }
        guard state.identity == nil else { return }
        let clientID = dependencies.random.makeClientID()
        try NovaAuthValidation.clientID(clientID)
        try setIdentity(NovaAuthInstallationIdentity(
            clientID: clientID, keyID: nil, registration: .unregistered
        ), context: context)
    }

    func start(flight: NovaAuthIssuanceFlight) {
        do {
            try validate(context: flight.context)
            guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
            switch identity.registration {
            case .unregistered:
                if identity.keyID == nil {
                    try createKey(flight: flight)
                } else { try challenge(flight: flight) }
            case let .appleDeferred(attempt):
                if try hasAttestationBudget(attempt) {
                    try attest(attempt: attempt, flight: flight)
                } else {
                    try setRegistration(.unregistered, flight: flight)
                    try challenge(flight: flight)
                }
            case .appleInFlight:
                try dropKey(flight: flight)
                throw NovaAuthError.keyUnavailable
            case .registrationPending, .registered:
                try issue(flight: flight)
            case .retired:
                try createKey(flight: flight)
            }
        } catch { fail(error, flight: flight) }
    }

    func handleBindingFailure(_ error: Error, flight: NovaAuthIssuanceFlight) throws {
        guard case let NovaAuthError.bootstrap(server) = error else { return }
        guard let identity = state?.identity else { return }
        guard server.statusCode == 401, server.code == "unknown_client" else { return }
        if case let .registrationPending(pending) = identity.registration {
            let now = try dependencies.clock.now()
            let start = pending.startedAt
            let elapsed = now.continuousSeconds - start.continuousSeconds
            if start.bootID == now.bootID, elapsed >= 0, elapsed < 120 { return }
        }
        try retire(.registrationAbandoned, flight: flight)
    }

    func createKey(flight: NovaAuthIssuanceFlight) throws {
        guard !flight.generatedKey else { throw NovaAuthError.keyUnavailable }
        flight.generatedKey = true
        guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
        let clientID: String
        if case let .retired(reason) = identity.registration, reason != .policyRefused {
            clientID = dependencies.random.makeClientID()
            try NovaAuthValidation.clientID(clientID)
        } else { clientID = identity.clientID }
        flight.step = .keyGeneration
        run(dependencies.appAttest.createKeyWrapper(), flight: flight) { [self] result in
            let keyID = try result.get()
            try NovaAuthValidation.keyID(keyID)
            try setIdentity(NovaAuthInstallationIdentity(
                clientID: clientID,
                keyID: keyID,
                registration: .unregistered,
                refusal: identity.refusal
            ), context: flight.context)
            try challenge(flight: flight)
        }
    }
}

private extension NovaAuth {
    func challenge(flight: NovaAuthIssuanceFlight) throws {
        guard let identity = state?.identity, let keyID = identity.keyID else { throw NovaAuthError.keyUnavailable }
        let start = try dependencies.clock.now()
        flight.step = .registrationChallenge
        run(
            bootstrap.createRegistrationChallengeWrapper(
                origin: flight.context.origin,
                clientID: identity.clientID,
                beforeSend: { [self] in try beforeBootstrapSend(flight: flight, step: .registrationChallenge) }
            ),
            flight: flight
        ) { [self] result in
            let challenge = try result.get()
            let bodyDigest = try Data(SHA256.hash(data: NovaAuthFraming.registrationPreimage(
                appIdentity: dependencies.appIdentity, keyID: keyID
            )))
            let hash = try NovaAuthFraming.clientDataHash(
                challenge: challenge.challenge,
                clientID: identity.clientID,
                origin: flight.context.origin,
                purpose: .registration,
                contentType: "application/json",
                bodyDigest: bodyDigest
            )
            let attempt = NovaAuthRegistrationAttempt(
                challenge: challenge.challenge,
                contentType: "application/json",
                clientDataHash: hash,
                startedAt: start
            )
            try attest(attempt: attempt, flight: flight)
        }
    }

    func attest(attempt: NovaAuthRegistrationAttempt, flight: NovaAuthIssuanceFlight) throws {
        guard let identity = state?.identity, let keyID = identity.keyID else { throw NovaAuthError.keyUnavailable }
        try validateAttemptBeforeApple(attempt, flight: flight)
        try setRegistration(.appleInFlight(attempt), flight: flight)
        flight.irreversible = true
        flight.step = .attestation
        let wrapper = dependencies.appAttest.createAttestationWrapper(
            keyID: keyID, clientDataHash: attempt.clientDataHash,
            beforeAttest: { [self] in
                try gate.novaAuthLocked {
                    guard self.flight === flight else { throw NovaAuthError.cancelled }
                    try validate(context: flight.context)
                    guard try hasAttestationBudget(attempt) else { throw NovaAuthError.keyUnavailable }
                }
            }
        )
        run(wrapper, flight: flight) { [self] result in
            let object = try attestation(from: result, attempt: attempt, flight: flight)
            try validateAttemptAfterApple(attempt, flight: flight)
            let now = try dependencies.clock.now()
            try validateAttestationObject(object, flight: flight)
            try setRegistration(.registrationPending(NovaAuthPendingRegistration(startedAt: now)), flight: flight)
            let request = NovaAuthRegistrationRequest(
                origin: flight.context.origin,
                clientID: identity.clientID,
                challenge: attempt.challenge,
                appIdentity: dependencies.appIdentity,
                keyID: keyID,
                attestation: object,
                contentType: attempt.contentType
            )
            let registerWrapper = bootstrap.createRegistrationWrapper(
                request,
                beforeSend: { [self] in try beforeBootstrapSend(flight: flight, step: .registration) }
            )
            flight.step = .registration
            run(registerWrapper, flight: flight) { [self] result in
                do {
                    try result.get()
                } catch {
                    try handleRegistrationFailure(error, flight: flight)
                    throw error
                }
                try setRegistration(.registered, flight: flight)
                try issue(flight: flight)
            }
        }
    }

    func attestation(
        from result: Result<Data, Error>,
        attempt: NovaAuthRegistrationAttempt,
        flight: NovaAuthIssuanceFlight
    ) throws -> Data {
        do {
            return try result.get()
        } catch NovaAuthAppAttestError.serverUnavailable {
            try setRegistration(.appleDeferred(attempt), flight: flight)
            throw NovaAuthAppAttestError.serverUnavailable
        } catch NovaAuthAppAttestError.invalidKey {
            try retire(.lostKey, flight: flight)
            throw NovaAuthAppAttestError.invalidKey
        } catch {
            try dropKey(flight: flight)
            throw error
        }
    }

    func validateAttestationObject(_ object: Data, flight: NovaAuthIssuanceFlight) throws {
        guard !object.isEmpty, object.count <= 49152 else {
            try dropKey(flight: flight)
            throw NovaAuthError.invalidResponse
        }
    }

    func validateAttemptBeforeApple(_ attempt: NovaAuthRegistrationAttempt, flight: NovaAuthIssuanceFlight) throws {
        guard try hasAttestationBudget(attempt) else {
            try setRegistration(.unregistered, flight: flight)
            throw NovaAuthError.keyUnavailable
        }
    }

    func hasAttestationBudget(_ attempt: NovaAuthRegistrationAttempt) throws -> Bool {
        let now = try dependencies.clock.now()
        let age = now.continuousSeconds - attempt.startedAt.continuousSeconds
        return now.bootID == attempt.startedAt.bootID && age >= 0 && age <= 40
    }

    func validateAttemptAfterApple(_ attempt: NovaAuthRegistrationAttempt, flight: NovaAuthIssuanceFlight) throws {
        let now = try dependencies.clock.now()
        let age = now.continuousSeconds - attempt.startedAt.continuousSeconds
        guard now.bootID == attempt.startedAt.bootID, age >= 0, age < 60 else {
            try dropKey(flight: flight)
            throw NovaAuthError.keyUnavailable
        }
    }

    func handleRegistrationFailure(_ error: Error, flight: NovaAuthIssuanceFlight) throws {
        guard case let NovaAuthError.bootstrap(server) = error, server.code != nil,
              (400 ... 499).contains(server.statusCode), server.statusCode != 429 else { return }
        if server.statusCode == 409 {
            try retire(.registrationRefused, flight: flight)
        } else {
            try refuse(flight: flight)
        }
    }
}
