import Foundation

protocol NovaAuthRedacted: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {}

extension NovaAuthRedacted {
    var description: String { "\(type(of: self))(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: EmptyCollection<(label: String?, value: Any)>()) }
}

extension NovaAuthTokenRecord: NovaAuthRedacted {}
extension NovaAuthTokenResponse: NovaAuthRedacted {}
extension NovaAuthInstallationState: NovaAuthRedacted {}
extension NovaAuthInstallationIdentity: NovaAuthRedacted {}
extension NovaAuthRegistrationState: NovaAuthRedacted {}
extension NovaAuthRegistrationAttempt: NovaAuthRedacted {}
extension NovaAuthPendingRegistration: NovaAuthRedacted {}
extension NovaAuthRegistrationRequest: NovaAuthRedacted {}
extension NovaAuthTokenRequest: NovaAuthRedacted {}
extension NovaAuthChallenge: NovaAuthRedacted {}
