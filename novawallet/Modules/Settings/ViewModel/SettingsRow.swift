import Foundation
import UIKit.UIImage

enum SettingsRow {
    case wallets
    case language
    case changePin
    case telegram
    case twitter
    case rateUs
    case website
    case github
    case terms
    case privacyPolicy
}

extension SettingsRow {
    func title(for locale: Locale) -> String {
        switch self {
        case .wallets:
            return R.string.localizable.profileWalletsTitle(preferredLanguages: locale.rLanguages)
        case .language:
            return R.string.localizable.profileLanguageTitle(preferredLanguages: locale.rLanguages)
        case .changePin:
            return R.string.localizable.profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        case .telegram:
            return R.string.localizable.aboutTelegram(preferredLanguages: locale.rLanguages)
        case .twitter:
            return R.string.localizable.settingsTwitter(preferredLanguages: locale.rLanguages)
        case .rateUs:
            return R.string.localizable.settingsRateUs(preferredLanguages: locale.rLanguages)
        case .website:
            return R.string.localizable.aboutWebsite(preferredLanguages: locale.rLanguages)
        case .github:
            return R.string.localizable.aboutGithub(preferredLanguages: locale.rLanguages)
        case .terms:
            return R.string.localizable.aboutTerms(preferredLanguages: locale.rLanguages)
        case .privacyPolicy:
            return R.string.localizable.aboutPrivacy(preferredLanguages: locale.rLanguages)
        }
    }

    var icon: UIImage? {
        switch self {
        case .wallets:
            return R.image.iconWallets()
        case .language:
            return R.image.iconLanguage()
        case .changePin:
            return R.image.iconPinCode()
        case .telegram:
            return R.image.iconTelegram()
        case .twitter:
            return R.image.iconTwitter()
        case .rateUs:
            return R.image.iconStar()
        case .website:
            return R.image.iconWebsite()
        case .github:
            return R.image.iconGithub()
        case .terms:
            return R.image.iconTerms()!
        case .privacyPolicy:
            return R.image.iconTerms()!
        }
    }
}
