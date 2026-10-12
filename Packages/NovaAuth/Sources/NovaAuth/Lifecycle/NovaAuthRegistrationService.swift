import Foundation
import CryptoKit

extension NovaAuth {
    func prepareIdentity(context: NovaAuthContext, intent: NovaAuthRequestIntent) throws {
        guard let state else { throw NovaAuthError.generationChanged }
        if state.requiresUserAction, intent != .userInitiated { throw NovaAuthError.userActionRequired }
        if let identity = state.identity {
            if case let .retired(reason) = identity.registration {
                guard reason != .policyRefused, intent == .userInitiated else { throw NovaAuthError.userActionRequired }
            } else { return }
        }
        let clientID = dependencies.random.makeClientID()
        try NovaAuthValidation.clientID(clientID)
        let identity = NovaAuthInstallationIdentity(clientID: clientID, keyID: nil, registration: .unregistered)
        try setIdentity(identity, context: context)
    }

    func start(flight: NovaAuthIssuanceFlight) {
        do {
            try validate(context: flight.context)
            guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
            switch identity.registration {
            case .unregistered:
                if identity.keyID == nil {
                    createKey(flight: flight)
                } else { try challenge(flight: flight) }
            case let .appleDeferred(attempt):
                try attest(attempt: attempt, flight: flight)
            case .appleInFlight:
                try setRegistration(.retired(.unrecoverableRegistration), flight: flight)
                throw NovaAuthError.userActionRequired
            case .registrationPending, .registered:
                try issue(flight: flight)
            case .retired:
                throw NovaAuthError.userActionRequired
            }
        } catch { fail(error, flight: flight) }
    }

    func handleChallengeFailure(_ error: Error, flight: NovaAuthIssuanceFlight) throws {
        guard case let NovaAuthError.bootstrap(server) = error else { return }
        guard let identity = state?.identity else { return }
        if server.code == "app_not_allowed" || server.code == "binding_not_allowed" {
            try setRegistration(.retired(.policyRefused), flight: flight)
            throw NovaAuthError.userActionRequired
        }
        if case let .registrationPending(pending) = identity.registration {
            let now = try dependencies.clock.now()
            let start = pending.startedAt
            let elapsed = now.continuousSeconds - start.continuousSeconds
            let unknown = server.code == "unknown_client"
            if unknown, start.bootID == now.bootID, elapsed >= 0, elapsed < 120, pending.probeCount < 8 { return }
            let final = unknown || (400 ... 499).contains(server.statusCode) && server.statusCode != 429
            if final {
                try setRegistration(.retired(.unrecoverableRegistration), flight: flight)
                throw NovaAuthError.userActionRequired
            }
        } else if server.code == "unknown_client" {
            try setRegistration(.retired(.unrecoverableRegistration), flight: flight)
            throw NovaAuthError.userActionRequired
        }
    }
}

private extension NovaAuth {
    func createKey(flight: NovaAuthIssuanceFlight) {
        run(dependencies.appAttest.createKeyWrapper(), flight: flight) { [self] result in
            let keyID = try result.get()
            try NovaAuthValidation.keyID(keyID)
            guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
            try setIdentity(NovaAuthInstallationIdentity(
                clientID: identity.clientID,
                keyID: keyID,
                registration: .unregistered
            ), context: flight.context)
            try challenge(flight: flight)
        }
    }

    func challenge(flight: NovaAuthIssuanceFlight) throws {
        guard let identity = state?.identity, let keyID = identity.keyID else { throw NovaAuthError.keyUnavailable }
        let start = try dependencies.clock.now()
        run(
            dependencies.bootstrap.createRegistrationChallengeWrapper(
                origin: flight.context.origin,
                clientID: identity.clientID,
                beforeSend: { [self] in try beforeBootstrapSend(flight: flight) }
            ),
            flight: flight
        ) { [self] result in
            let challenge = try result.get()
            let bodyDigest = Data(SHA256.hash(data: try NovaAuthFraming.registrationPreimage(
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
        try setRegistration(.appleInFlight(attempt), flight: flight)
        flight.irreversible = true
        let wrapper = dependencies.appAttest.createAttestationWrapper(
            keyID: keyID, clientDataHash: attempt.clientDataHash
        )
        run(wrapper, flight: flight) { [self] result in
            let object: Data
            do {
                object = try result.get()
            } catch NovaAuthAppAttestError.serverUnavailable {
                try setRegistration(.appleDeferred(attempt), flight: flight)
                throw NovaAuthAppAttestError.serverUnavailable
            } catch {
                try setRegistration(.retired(.unrecoverableRegistration), flight: flight)
                throw error
            }
            let now = try dependencies.clock.now()
            let age = now.continuousSeconds - attempt.startedAt.continuousSeconds
            guard now.bootID == attempt.startedAt.bootID, age >= 0, age < 60 else {
                try setRegistration(.retired(.unrecoverableRegistration), flight: flight)
                throw NovaAuthError.userActionRequired
            }
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
            let registerWrapper = dependencies.bootstrap.createRegistrationWrapper(
                request,
                beforeSend: { [self] in try beforeBootstrapSend(flight: flight, registration: true) }
            )
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

    func validateAttestationObject(_ object: Data, flight: NovaAuthIssuanceFlight) throws {
        guard !object.isEmpty, object.count <= 49152 else {
            try setRegistration(.retired(.unrecoverableRegistration), flight: flight)
            throw NovaAuthError.invalidResponse
        }
    }

    func handleRegistrationFailure(_ error: Error, flight: NovaAuthIssuanceFlight) throws {
        guard case let NovaAuthError.bootstrap(server) = error else { return }
        if (400 ... 499).contains(server.statusCode), server.statusCode != 429, server.code != "invalid_proof" {
            let policy = server.code == "app_not_allowed" || server.code == "binding_not_allowed"
            try setRegistration(.retired(policy ? .policyRefused : .unrecoverableRegistration), flight: flight)
        }
    }
}
