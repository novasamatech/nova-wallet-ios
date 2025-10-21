import Foundation
import UIKit.UIImage

enum SettingsRow {
    case wallets
    case currency
    case language
    case biometricAuth
    case approveWithPin
    case hideBalances
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
            R.string(preferredLanguages: locale.rLanguages).localizable.profileWalletsTitle()
        case .currency:
            R.string(preferredLanguages: locale.rLanguages).localizable.profileCurrencyTitle()
        case .language:
            R.string(preferredLanguages: locale.rLanguages).localizable.profileLanguageTitle()
        case .biometricAuth:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsBiometricAuth()
        case .approveWithPin:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsApproveWithPin()
        case .hideBalances:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsHideBalancesOnLaunch()
        case .changePin:
            R.string(preferredLanguages: locale.rLanguages).localizable.profilePincodeChangeTitle()
        case .telegram:
            R.string(preferredLanguages: locale.rLanguages).localizable.aboutTelegram()
        case .youtube:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsYoutube()
        case .twitter:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsTwitter()
        case .rateUs:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsRateUs()
        case .email:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsEmail()
        case .website:
            R.string(preferredLanguages: locale.rLanguages).localizable.aboutWebsite()
        case .github:
            R.string(preferredLanguages: locale.rLanguages).localizable.aboutGithub()
        case .terms:
            R.string(preferredLanguages: locale.rLanguages).localizable.aboutTerms()
        case .privacyPolicy:
            R.string(preferredLanguages: locale.rLanguages).localizable.aboutPrivacy()
        case .walletConnect:
            R.string(preferredLanguages: locale.rLanguages).localizable.commonWalletConnect()
        case .wiki:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsWiki()
        case .notifications:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsPushNotifications()
        case .backup:
            R.string(preferredLanguages: locale.rLanguages).localizable.commonBackup()
        case .networks:
            R.string(preferredLanguages: locale.rLanguages).localizable.connectionManagementTitle()
        case .appearance:
            R.string(preferredLanguages: locale.rLanguages).localizable.settingsAppearance()
        }
    }

    var icon: UIImage? {
        switch self {
        case .wallets:
            R.image.iconWallets()
        case .currency:
            R.image.iconCurrency()
        case .language:
            R.image.iconLanguage()
        case .biometricAuth:
            R.image.iconBiometricAuth()
        case .approveWithPin:
            R.image.iconApproveWithPin()
        case .hideBalances:
            R.image.iconHideBalances()
        case .changePin:
            R.image.iconPincode()
        case .telegram:
            R.image.iconTelegram()
        case .youtube:
            R.image.iconYoutube()
        case .twitter:
            R.image.iconTwitter()
        case .rateUs:
            R.image.iconStar()
        case .email:
            R.image.iconEmail()
        case .website:
            R.image.iconWebsite()
        case .github:
            R.image.iconGithub()
        case .terms:
            R.image.iconTerms()
        case .privacyPolicy:
            R.image.iconTerms()
        case .walletConnect:
            R.image.iconWalletConnect()
        case .wiki:
            R.image.iconWiki()
        case .notifications:
            R.image.iconNotification()
        case .backup:
            R.image.iconSettingsBackup()
        case .networks:
            R.image.iconNetworks()
        case .appearance:
            R.image.iconAppearance()
        }
    }
}
