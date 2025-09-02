import Foundation
import UIKit.UIImage

enum SettingsRow {
    case wallets
    case currency
    case language
    case biometricAuth
    case approveWithPin
    case changePin
    case telegram
    case youtube
    case twitter
    case rateUs
    case email
    case website
    case github
    case terms
    case privacyPolicy
    case walletConnect
    case wiki
    case notifications
    case backup
    case networks
    case appearance
}

extension SettingsRow {
    // swiftlint:disable:next cyclomatic_complexity
    func title(for locale: Locale) -> String {
        switch self {
        case .wallets:
            return R.string.localizable.profileWalletsTitle(preferredLanguages: locale.rLanguages)
        case .currency:
            return R.string.localizable.profileCurrencyTitle(preferredLanguages: locale.rLanguages)
        case .language:
            return R.string.localizable.profileLanguageTitle(preferredLanguages: locale.rLanguages)
        case .biometricAuth:
            return R.string.localizable.settingsBiometricAuth(preferredLanguages: locale.rLanguages)
        case .approveWithPin:
            return R.string.localizable.settingsApproveWithPin(preferredLanguages: locale.rLanguages)
        case .changePin:
            return R.string.localizable.profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        case .telegram:
            return R.string.localizable.aboutTelegram(preferredLanguages: locale.rLanguages)
        case .youtube:
            return R.string.localizable.settingsYoutube(preferredLanguages: locale.rLanguages)
        case .twitter:
            return R.string.localizable.settingsTwitter(preferredLanguages: locale.rLanguages)
        case .rateUs:
            return R.string.localizable.settingsRateUs(preferredLanguages: locale.rLanguages)
        case .email:
            return R.string.localizable.settingsEmail(preferredLanguages: locale.rLanguages)
        case .website:
            return R.string.localizable.aboutWebsite(preferredLanguages: locale.rLanguages)
        case .github:
            return R.string.localizable.aboutGithub(preferredLanguages: locale.rLanguages)
        case .terms:
            return R.string.localizable.aboutTerms(preferredLanguages: locale.rLanguages)
        case .privacyPolicy:
            return R.string.localizable.aboutPrivacy(preferredLanguages: locale.rLanguages)
        case .walletConnect:
            return R.string.localizable.commonWalletConnect(preferredLanguages: locale.rLanguages)
        case .wiki:
            return R.string.localizable.settingsWiki(preferredLanguages: locale.rLanguages)
        case .notifications:
            return R.string.localizable.settingsPushNotifications(preferredLanguages: locale.rLanguages)
        case .backup:
            return R.string.localizable.commonBackup(preferredLanguages: locale.rLanguages)
        case .networks:
            return R.string.localizable.connectionManagementTitle(preferredLanguages: locale.rLanguages)
        case .appearance:
            return R.string.localizable.settingsAppearance(preferredLanguages: locale.rLanguages)
        }
    }

    var icon: UIImage? {
        switch self {
        case .wallets:
            return R.image.iconWallets()
        case .currency:
            return R.image.iconCurrency()
        case .language:
            return R.image.iconLanguage()
        case .biometricAuth:
            return R.image.iconBiometricAuth()
        case .approveWithPin:
            return R.image.iconApproveWithPin()
        case .changePin:
            return R.image.iconPincode()
        case .telegram:
            return R.image.iconTelegram()
        case .youtube:
            return R.image.iconYoutube()
        case .twitter:
            return R.image.iconTwitter()
        case .rateUs:
            return R.image.iconStar()
        case .email:
            return R.image.iconEmail()
        case .website:
            return R.image.iconWebsite()
        case .github:
            return R.image.iconGithub()
        case .terms:
            return R.image.iconTerms()!
        case .privacyPolicy:
            return R.image.iconTerms()!
        case .walletConnect:
            return R.image.iconWalletConnect()!
        case .wiki:
            return R.image.iconWiki()!
        case .notifications:
            return R.image.iconNotification()!
        case .backup:
            return R.image.iconSettingsBackup()!
        case .networks:
            return R.image.iconNetworks()!
        case .appearance:
            return R.image.iconAppearance()!
        }
    }
}
