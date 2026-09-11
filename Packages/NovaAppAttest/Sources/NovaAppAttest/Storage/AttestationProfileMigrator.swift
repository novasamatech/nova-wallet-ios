import Foundation
import Keystore_iOS

/// Retires an installation that was bound under an earlier crypto profile.
///
/// The gateway never promotes an old binding to a new profile. A legacy client identifier answers a
/// request challenge with 403 `binding_not_allowed` and a re-registration with 409
/// `client_already_registered`, so an upgraded install that keeps its identifier can never attest
/// again — and because the identifier is refused, the advice for both codes is to stop retrying.
/// The key goes with it: Apple attests a key once, and the gateway will not rebind an identifier to
/// a different one.
public enum AttestationProfileMigrator {
    /// Idempotent and settings-only, so it is safe on every launch. A fresh install simply records
    /// the current profile and retires nothing.
    public static func migrate(settingsManager: SettingsManagerProtocol) {
        guard settingsManager.gatewayAttestationProfile != AttestationProfile2.version else {
            return
        }

        settingsManager.gatewayAttestationClientId = nil
        settingsManager.removeValue(for: SettingsAppAttestKeyRepository.storageKey)
        settingsManager.gatewayAttestationProfile = AttestationProfile2.version
    }
}
