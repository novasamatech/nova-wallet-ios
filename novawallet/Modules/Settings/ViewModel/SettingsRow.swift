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
            R.string.localizable.profileWalletsTitle(preferredLanguages: locale.rLanguages)
        case .currency:
            R.string.localizable.profileCurrencyTitle(preferredLanguages: locale.rLanguages)
        case .language:
            R.string.localizable.profileLanguageTitle(preferredLanguages: locale.rLanguages)
        case .biometricAuth:
            R.string.localizable.settingsBiometricAuth(preferredLanguages: locale.rLanguages)
        case .approveWithPin:
            R.string.localizable.settingsApproveWithPin(preferredLanguages: locale.rLanguages)
        case .hideBalances:
            R.string.localizable.settingsHideBalancesOnLaunch(preferredLanguages: locale.rLanguages)
        case .changePin:
            R.string.localizable.profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        case .telegram:
            R.string.localizable.aboutTelegram(preferredLanguages: locale.rLanguages)
        case .youtube:
            R.string.localizable.settingsYoutube(preferredLanguages: locale.rLanguages)
        case .twitter:
            R.string.localizable.settingsTwitter(preferredLanguages: locale.rLanguages)
        case .rateUs:
            R.string.localizable.settingsRateUs(preferredLanguages: locale.rLanguages)
        case .email:
            R.string.localizable.settingsEmail(preferredLanguages: locale.rLanguages)
        case .website:
            R.string.localizable.aboutWebsite(preferredLanguages: locale.rLanguages)
        case .github:
            R.string.localizable.aboutGithub(preferredLanguages: locale.rLanguages)
        case .terms:
            R.string.localizable.aboutTerms(preferredLanguages: locale.rLanguages)
        case .privacyPolicy:
            R.string.localizable.aboutPrivacy(preferredLanguages: locale.rLanguages)
        case .walletConnect:
            R.string.localizable.commonWalletConnect(preferredLanguages: locale.rLanguages)
        case .wiki:
            R.string.localizable.settingsWiki(preferredLanguages: locale.rLanguages)
        case .notifications:
            R.string.localizable.settingsPushNotifications(preferredLanguages: locale.rLanguages)
        case .backup:
            R.string.localizable.commonBackup(preferredLanguages: locale.rLanguages)
        case .networks:
            R.string.localizable.connectionManagementTitle(preferredLanguages: locale.rLanguages)
        case .appearance:
            R.string.localizable.settingsAppearance(preferredLanguages: locale.rLanguages)
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
