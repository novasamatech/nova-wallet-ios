import Foundation
import Keystore_iOS

extension SettingsManagerProtocol {
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
    // Stable on-disk settings key: changing this string orphans stored values.
    static let gatewayAttestationClientId = "gatewayAttestationClientId"
}
