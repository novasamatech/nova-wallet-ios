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
            return R.string.localizable.settingsGeneral(preferredLanguages: locale.rLanguages).uppercased()
        case .preferences:
            return R.string.localizable.settingsPreferences(preferredLanguages: locale.rLanguages).uppercased()
        case .security:
            return R.string.localizable.settingsSecurity(preferredLanguages: locale.rLanguages).uppercased()
        case .community:
            return R.string.localizable.settingsCommunity(preferredLanguages: locale.rLanguages).uppercased()
        case .support:
            return R.string.localizable.settingsSupport(preferredLanguages: locale.rLanguages).uppercased()
        case .about:
            return R.string.localizable.aboutTitle(preferredLanguages: locale.rLanguages).uppercased()
        }
    }
}
