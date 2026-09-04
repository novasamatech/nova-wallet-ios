import Foundation
import Keystore_iOS

/// Deliberately `internal`, for the same reason `Data+Sha256.swift` is: `public` would add a
/// member to *every* `SettingsManagerProtocol` in any module that imports `NovaAppAttest`,
/// including app files that already see the app's own extensions on that protocol. It also
/// generalises badly — `NovaAnalytics` carries `analyticsInstallId` the same way, and two
/// packages writing into one third-party protocol's namespace is a collision waiting for a
/// third. `BackendAttestationIdentity` is the only reader, and the package's own tests reach
/// this through `@testable`; anything outside the module reads the value with
/// `string(for: "gatewayAttestationClientId")`.
extension SettingsManagerProtocol {
    /// A bare string literal rather than an app `SettingsKey` case, for the same reason
    /// `SettingsAppAttestKeyRepository.storageKey` is one: this package cannot depend on the
    /// app's key enum. The literal is exactly the raw value that enum produced, so an
    /// install that already holds a client id keeps it across this move.
    ///
    /// Lives here rather than in the app because `BackendAttestationIdentity` is the only
    /// writer: leaving a second definition behind in the app would let the two drift onto
    /// different keys with nothing to catch it.
    var gatewayAttestationClientId: String? {
        get {
            string(for: AttestationSettingsKey.gatewayAttestationClientId)
        }

        set {
            if let newValue {
                set(value: newValue, for: AttestationSettingsKey.gatewayAttestationClientId)
            } else {
                removeValue(for: AttestationSettingsKey.gatewayAttestationClientId)
            }
        }
    }
}

enum AttestationSettingsKey {
    static let gatewayAttestationClientId = "gatewayAttestationClientId"
}
