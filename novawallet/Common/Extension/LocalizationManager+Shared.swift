import Foundation
import SoraFoundation
import SoraKeystore

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
