import Foundation
import Keystore_iOS

extension SettingsManagerProtocol {
    var gatewayAttestationClientId: String? {
        get {
            attestationClientId(for: AttestationSettingsKey.gatewayAttestationClientId)
        }

        set {
            setAttestationClientId(newValue, for: AttestationSettingsKey.gatewayAttestationClientId)
        }
    }

    func attestationClientId(for storageKey: String) -> String? {
        string(for: storageKey)
    }

    func setAttestationClientId(_ clientId: String?, for storageKey: String) {
        if let clientId {
            set(value: clientId, for: storageKey)
        } else {
            removeValue(for: storageKey)
        }
    }
}

public enum AttestationSettingsKey {
    // Stable on-disk settings key: changing this string orphans stored values.
    public static let gatewayAttestationClientId = "gatewayAttestationClientId"
    public static let appAttestKeys = "appAttestKeys"
}
