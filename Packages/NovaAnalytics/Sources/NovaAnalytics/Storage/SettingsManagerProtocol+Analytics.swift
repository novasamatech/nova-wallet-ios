import Foundation
import Keystore_iOS

extension SettingsManagerProtocol {
    var isAnalyticsEnabled: Bool {
        get {
            bool(for: AnalyticsSettingsKey.analyticsEnabled) ?? false
        }

        set {
            set(value: newValue, for: AnalyticsSettingsKey.analyticsEnabled)
        }
    }

    var analyticsPromptSeen: Bool {
        get {
            bool(for: AnalyticsSettingsKey.analyticsPromptSeen) ?? false
        }

        set {
            set(value: newValue, for: AnalyticsSettingsKey.analyticsPromptSeen)
        }
    }

    var analyticsInstallId: String? {
        get {
            string(for: AnalyticsSettingsKey.analyticsInstallId)
        }

        set {
            if let newValue {
                set(value: newValue, for: AnalyticsSettingsKey.analyticsInstallId)
            } else {
                removeValue(for: AnalyticsSettingsKey.analyticsInstallId)
            }
        }
    }

    var isAnalyticsErasureOwed: Bool {
        get {
            bool(for: AnalyticsSettingsKey.analyticsErasureOwed) ?? false
        }

        set {
            set(value: newValue, for: AnalyticsSettingsKey.analyticsErasureOwed)
        }
    }

    var analyticsConsentEpoch: Int {
        get {
            integer(for: AnalyticsSettingsKey.analyticsConsentEpoch) ?? 0
        }

        set {
            set(value: newValue, for: AnalyticsSettingsKey.analyticsConsentEpoch)
        }
    }
}

enum AnalyticsSettingsKey {
    // Stable on-disk settings keys: changing these strings orphans stored values.
    static let analyticsEnabled = "analyticsEnabled"
    static let analyticsPromptSeen = "analyticsPromptSeen"
    static let analyticsInstallId = "analyticsInstallId"
    static let analyticsErasureOwed = "analyticsErasureOwed"
    static let analyticsConsentEpoch = "analyticsConsentEpoch"
}
