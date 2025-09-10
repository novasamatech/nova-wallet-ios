import Foundation

enum SettingsSection {
    case general
    case preferences
    case security
    case community
    case support
    case about
}

extension SettingsSection {
    func title(for locale: Locale) -> String {
        switch self {
        case .general:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsGeneral().uppercased()
        case .preferences:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsPreferences().uppercased()
        case .security:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsSecurity().uppercased()
        case .community:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsCommunity().uppercased()
        case .support:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsSupport().uppercased()
        case .about:
            return R.string(preferredLanguages: locale.rLanguages).localizable.aboutTitle().uppercased()
        }
    }
}
