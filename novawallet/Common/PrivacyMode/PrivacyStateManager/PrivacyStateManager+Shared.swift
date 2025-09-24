import Foundation
import Keystore_iOS

extension PrivacyStateManager {
    static let shared: PrivacyStateManagerProtocol = PrivacyStateManager(
        settingsManager: SettingsManager.shared
    )
}
