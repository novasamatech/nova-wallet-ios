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
            return R.string(preferredLanguages: locale.rLanguages).localizable.profileWalletsTitle()
        case .currency:
            return R.string(preferredLanguages: locale.rLanguages).localizable.profileCurrencyTitle()
        case .language:
            return R.string(preferredLanguages: locale.rLanguages).localizable.profileLanguageTitle()
        case .biometricAuth:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsBiometricAuth()
        case .approveWithPin:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsApproveWithPin()
        case .changePin:
            return R.string(preferredLanguages: locale.rLanguages).localizable.profilePincodeChangeTitle()
        case .telegram:
            return R.string(preferredLanguages: locale.rLanguages).localizable.aboutTelegram()
        case .youtube:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsYoutube()
        case .twitter:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsTwitter()
        case .rateUs:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsRateUs()
        case .email:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsEmail()
        case .website:
            return R.string(preferredLanguages: locale.rLanguages).localizable.aboutWebsite()
        case .github:
            return R.string(preferredLanguages: locale.rLanguages).localizable.aboutGithub()
        case .terms:
            return R.string(preferredLanguages: locale.rLanguages).localizable.aboutTerms()
        case .privacyPolicy:
            return R.string(preferredLanguages: locale.rLanguages).localizable.aboutPrivacy()
        case .walletConnect:
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonWalletConnect()
        case .wiki:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsWiki()
        case .notifications:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsPushNotifications()
        case .backup:
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonBackup()
        case .networks:
            return R.string(preferredLanguages: locale.rLanguages).localizable.connectionManagementTitle()
        case .appearance:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsAppearance()
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
