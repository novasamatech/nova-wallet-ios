import UIKit
import Foundation
import Keystore_iOS

protocol PrivacyStateManagerProtocol: AnyObject {
    var settingsEnabled: Bool { get set }

    var lastEnabled: Bool { get set }

    func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Bool, Bool) -> Void
    )

    func removeObserver(by owner: AnyObject)
}

final class PrivacyStateManager: Observable<Bool>, PrivacyStateManagerProtocol {
    private let settingsManager: SettingsManagerProtocol

    var settingsEnabled: Bool {
        get {
            settingsManager.privacyModeSettings.privacySettingsEnabled
        }
        set {
            updateState(with: settingsManager.privacyModeSettings
                .with(privacySettingsEnabled: newValue))
        }
    }

    var lastEnabled: Bool {
        get {
            settingsManager.privacyModeSettings.lastEnabled
        }
        set {
            updateState(with: settingsManager.privacyModeSettings
                .with(lastEnabled: newValue))
        }
    }

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager

        super.init(state: settingsManager.privacyModeSettings.enabled)
    }

    private func updateState(with updatedSettings: PrivacyModeSettings) {
        settingsManager.privacyModeSettings = updatedSettings

        guard state != updatedSettings.enabled else { return }

        state = updatedSettings.enabled
    }
}

extension PrivacyStateManager {
    static let shared: PrivacyStateManagerProtocol = PrivacyStateManager(
        settingsManager: SettingsManager.shared
    )
}
