import Foundation
import Keystore_iOS

protocol ConsentServiceProtocol {
    var currentConsentVersion: Int { get }
    var acceptedConsentVersion: Int? { get }
    var hasAcceptedCurrentVersion: Bool { get }

    func acceptCurrentConsent()
}

final class ConsentService: ConsentServiceProtocol {
    private enum Keys {
        static let acceptedVersion = "consentAcceptedVersion"
    }

    let currentConsentVersion: Int

    private let settingsManager: SettingsManagerProtocol

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager.shared,
        currentConsentVersion: Int = ConsentBannerConstants.currentConsentVersion
    ) {
        self.settingsManager = settingsManager
        self.currentConsentVersion = currentConsentVersion
    }

    var acceptedConsentVersion: Int? {
        settingsManager.integer(for: Keys.acceptedVersion)
    }

    var hasAcceptedCurrentVersion: Bool {
        guard let accepted = acceptedConsentVersion else {
            return false
        }

        return accepted >= currentConsentVersion
    }

    func acceptCurrentConsent() {
        settingsManager.set(value: currentConsentVersion, for: Keys.acceptedVersion)
    }
}
