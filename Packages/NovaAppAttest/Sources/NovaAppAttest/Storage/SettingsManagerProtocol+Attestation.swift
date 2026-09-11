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

extension SettingsManagerProtocol {
    var gatewayAttestationProfile: Int? {
        get {
            integer(for: AttestationSettingsKey.gatewayAttestationProfile)
        }

        set {
            if let newValue {
                set(value: newValue, for: AttestationSettingsKey.gatewayAttestationProfile)
            } else {
                removeValue(for: AttestationSettingsKey.gatewayAttestationProfile)
            }
        }
    }
}

enum AttestationSettingsKey {
    // Stable on-disk settings keys: changing these strings orphans stored values.
    static let gatewayAttestationClientId = "gatewayAttestationClientId"
    static let gatewayAttestationProfile = "gatewayAttestationProfile"
}
