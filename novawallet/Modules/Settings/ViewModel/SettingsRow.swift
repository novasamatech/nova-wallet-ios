import Foundation
import UIKit.UIImage

enum SettingsRow {
    case wallets
    case currency
    case language
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
}

extension SettingsRow {
    // swiftlint:disable:next cyclomatic_complexity
    func title(for locale: Locale) -> String {
        titleLocalizationAction(locale.rLanguages)
    }

    var titleLocalizationAction: ([String]?) -> String {
        let strings = R.string.localizable.self
        switch self {
        case .wallets:
            return strings.profileWalletsTitle
        case .currency:
            return strings.profileCurrencyTitle
        case .language:
            return strings.profileLanguageTitle
        case .changePin:
            return strings.profilePincodeChangeTitle
        case .telegram:
            return strings.aboutTelegram
        case .youtube:
            return strings.settingsYoutube
        case .twitter:
            return strings.settingsTwitter
        case .rateUs:
            return strings.settingsRateUs
        case .email:
            return strings.settingsEmail
        case .website:
            return strings.aboutWebsite
        case .github:
            return strings.aboutGithub
        case .terms:
            return strings.aboutTerms
        case .privacyPolicy:
            return strings.aboutPrivacy
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
        case .changePin:
            return R.image.iconPinCode()
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
        }
    }
}
