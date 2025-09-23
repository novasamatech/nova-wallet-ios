import UIKit
import Foundation
import Keystore_iOS

protocol PrivacyStateManagerProtocol: AnyObject {
    var enablePrivacyModeOnLaunch: Bool { get set }

    var privacyModeEnabled: Bool { get set }

    func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Bool, Bool) -> Void
    )

    func addObserver(
        with owner: AnyObject,
        closure: @escaping (Bool, Bool) -> Void
    )

    func removeObserver(by owner: AnyObject)
}

final class PrivacyStateManager: Observable<Bool> {
    private let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager

        var privacyModeSettings = settingsManager.privacyModeSettings

        // If `enablePrivacyModeOnLaunch` is enabled, force-enable privacy mode
        if privacyModeSettings.enablePrivacyModeOnLaunch, !privacyModeSettings.privacyModeEnabled {
            privacyModeSettings = privacyModeSettings.with(privacyModeEnabled: true)
            settingsManager.privacyModeSettings = privacyModeSettings
        }

        super.init(state: privacyModeSettings.privacyModeEnabled)
    }
}

// MARK: - Private

private extension PrivacyStateManager {
    func updateState(with updatedSettings: PrivacyModeSettings) {
        settingsManager.privacyModeSettings = updatedSettings

        guard state != updatedSettings.privacyModeEnabled else { return }

        state = updatedSettings.privacyModeEnabled
    }
}

// MARK: - PrivacyStateManagerProtocol

extension PrivacyStateManager: PrivacyStateManagerProtocol {
    var enablePrivacyModeOnLaunch: Bool {
        get {
            settingsManager.privacyModeSettings.enablePrivacyModeOnLaunch
        }
        set {
            updateState(with: settingsManager.privacyModeSettings
                .with(enablePrivacyModeOnLaunch: newValue))
        }
    }

    var privacyModeEnabled: Bool {
        get {
            state
        }
        set {
            updateState(with: settingsManager.privacyModeSettings
                .with(privacyModeEnabled: newValue))
        }
    }
}
