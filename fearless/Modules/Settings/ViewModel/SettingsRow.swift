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
            return "Twitter"
        case .rateUs:
            return "Rate us"
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
            return R.image.iconProfileAccounts()!
        case .language:
            return R.image.iconProfileLanguage()!
        case .changePin:
            return R.image.iconProfilePin()!
        case .telegram:
            return R.image.iconAboutTg()!
        case .twitter:
            return R.image.iconTwitter()!
        case .rateUs:
            return R.image.iconStar()!
        case .website:
            return R.image.iconAboutWeb()!
        case .github:
            return R.image.iconAboutGit()!
        case .terms:
            return R.image.iconTerms()!
        case .privacyPolicy:
            return R.image.iconTerms()!
        }
    }
}
