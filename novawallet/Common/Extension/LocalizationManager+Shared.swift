import Foundation
import Foundation_iOS
import Keystore_iOS

extension LocalizationManagerProtocol {
    var preferredLocalizations: [String]? {
        [selectedLocalization]
    }

    var selectedLanguage: Language {
        Language(code: selectedLocalization)
    }
}

extension LocalizationManager {
    static let shared = LocalizationManager(
        settings: SharedSettingsManager() ?? SettingsManager.shared,
        key: SharedSettingsKey.selectedLocalization.rawValue
    )
}
