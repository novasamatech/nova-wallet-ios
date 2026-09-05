import Foundation
import Keystore_iOS

/// Deliberately `internal`, for the same reason `NovaAppAttest`'s
/// `SettingsManagerProtocol+Attestation.swift` is: `public` would add three members to
/// *every* `SettingsManagerProtocol` in any module that imports `NovaAnalytics`, including
/// app files that already see the app's own extensions on that protocol. `AnalyticsIdentity`
/// and `AnalyticsConsentManager` are the only readers, and the package's own tests reach
/// these through `@testable`; anything outside the module reads a value with
/// `string(for: "analyticsInstallId")` and friends.
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
}

/// Bare string literals rather than the app's `SettingsKey` cases, which this package cannot
/// depend on. Each literal is exactly the raw value that enum produced, so an install that
/// already holds a consent flag or an install id keeps it across this move.
enum AnalyticsSettingsKey {
    static let analyticsEnabled = "analyticsEnabled"
    static let analyticsPromptSeen = "analyticsPromptSeen"
    static let analyticsInstallId = "analyticsInstallId"
}
