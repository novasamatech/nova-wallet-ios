import Foundation

extension NovaAuth {
    func retire(_ reason: NovaAuthRetirementReason, flight: NovaAuthIssuanceFlight) throws {
        try validate(context: flight.context)
        guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
        try setIdentity(NovaAuthInstallationIdentity(
            clientID: identity.clientID,
            keyID: identity.keyID,
            registration: .retired(reason),
            refusal: identity.refusal
        ), context: flight.context)
    }

    func refuse(flight: NovaAuthIssuanceFlight) throws {
        try dropKey(flight: flight, refusal: nextRefusal())
    }

    func refuseBinding(flight: NovaAuthIssuanceFlight) throws {
        try validate(context: flight.context)
        guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
        try setIdentity(NovaAuthInstallationIdentity(
            clientID: identity.clientID,
            keyID: identity.keyID,
            registration: identity.registration,
            refusal: nextRefusal()
        ), context: flight.context)
    }

    func dropKey(flight: NovaAuthIssuanceFlight, refusal: NovaAuthRefusal? = nil) throws {
        try validate(context: flight.context)
        guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
        try setIdentity(NovaAuthInstallationIdentity(
            clientID: identity.clientID, keyID: nil, registration: .unregistered, refusal: refusal ?? identity.refusal
        ), context: flight.context)
    }

    private func nextRefusal() throws -> NovaAuthRefusal {
        try NovaAuthRefusal(
            now: dependencies.clock.now(),
            previous: state?.identity?.refusal,
            appVersion: dependencies.appIdentity.version
        )
    }
}
