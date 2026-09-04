import Foundation
import Keystore_iOS

public extension SettingsManagerProtocol {
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
