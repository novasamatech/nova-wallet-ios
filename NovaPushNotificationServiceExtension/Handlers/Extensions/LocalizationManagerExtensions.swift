import SoraFoundation

extension LocalizationManager {
    func refreshLocale() {
        if let settingsKey = settingsKey,
           let localization = settings?.string(for: settingsKey) {
            selectedLocalization = localization
        }
    }
}