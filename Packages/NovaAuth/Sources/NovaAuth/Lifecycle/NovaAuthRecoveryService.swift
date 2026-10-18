import Foundation

extension NovaAuth {
    func retire(_ reason: NovaAuthRetirementReason, flight: NovaAuthIssuanceFlight) throws {
        try validate(context: flight.context)
        guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
        try setIdentity(NovaAuthInstallationIdentity(
            clientID: identity.clientID, keyID: identity.keyID, registration: .retired(reason)
        ), context: flight.context)
    }

    func refuse(flight: NovaAuthIssuanceFlight) throws {
        try validate(context: flight.context)
        guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
        try setIdentity(NovaAuthInstallationIdentity(
            clientID: identity.clientID, keyID: nil, registration: .unregistered
        ), context: flight.context)
    }
}
