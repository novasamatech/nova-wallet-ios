import Foundation
import Keystore_iOS

extension SettingsManagerProtocol {
    var isAnalyticsEnabled: Bool {
        get {
            bool(for: SettingsKey.analyticsEnabled.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.analyticsEnabled.rawValue)
        }
    }

    var analyticsPromptSeen: Bool {
        get {
            bool(for: SettingsKey.analyticsPromptSeen.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.analyticsPromptSeen.rawValue)
        }
    }

    var analyticsInstallId: String? {
        get {
            string(for: SettingsKey.analyticsInstallId.rawValue)
        }

        set {
            if let newValue {
                set(value: newValue, for: SettingsKey.analyticsInstallId.rawValue)
            } else {
                removeValue(for: SettingsKey.analyticsInstallId.rawValue)
            }
        }
    }

    var gatewayAttestationClientId: String? {
        get {
            string(for: SettingsKey.gatewayAttestationClientId.rawValue)
        }

        set {
            if let newValue {
                set(value: newValue, for: SettingsKey.gatewayAttestationClientId.rawValue)
            } else {
                removeValue(for: SettingsKey.gatewayAttestationClientId.rawValue)
            }
        }
    }
}
