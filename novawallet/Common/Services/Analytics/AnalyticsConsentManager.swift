import Foundation
import Keystore_iOS

final class AnalyticsConsentManager: Observable<Bool> {
    private let settingsManager: SettingsManagerProtocol
    private let availabilityProvider: AnalyticsAvailabilityProviderProtocol

    init(
        settingsManager: SettingsManagerProtocol,
        availabilityProvider: AnalyticsAvailabilityProviderProtocol
    ) {
        self.settingsManager = settingsManager
        self.availabilityProvider = availabilityProvider

        super.init(state: settingsManager.isAnalyticsEnabled)
    }
}

// MARK: - AnalyticsConsentManagerProtocol

extension AnalyticsConsentManager: AnalyticsConsentManagerProtocol {
    var isEnabled: Bool { state }

    var isAvailable: Bool { availabilityProvider.isAvailable }

    var isPromptSeen: Bool { settingsManager.analyticsPromptSeen }

    /// Only flips the flag and notifies. The opt-out wipe belongs to `AnalyticsService`,
    /// which observes this manager: the manager owns no queue, identity or attestation.
    func setEnabled(_ enabled: Bool) {
        settingsManager.isAnalyticsEnabled = enabled
        state = enabled
    }

    /// Never cleared — re-onboarding must not re-ask; the Settings switch is the way back.
    func markPromptSeen() {
        settingsManager.analyticsPromptSeen = true
    }
}
