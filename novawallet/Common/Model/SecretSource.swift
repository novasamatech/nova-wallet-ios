import Foundation
import UIKit

enum SecretSource {
    case mnemonic
    case seed
    case keystore
}

extension SecretSource {
    static var displayOptions: [SecretSource] { [.mnemonic, .seed, .keystore] }

    func titleForLocale(_ locale: Locale?) -> String {
        switch self {
        case .keystore:
            return R.string.localizable.secretTypeKeystoreTitle(preferredLanguages: locale?.rLanguages)
        case .seed:
            return R.string.localizable.secretTypeSeedTitle(preferredLanguages: locale?.rLanguages)
        case .mnemonic:
            return R.string.localizable.secretTypeMnemonicTitle(preferredLanguages: locale?.rLanguages)
        }
    }

    func subtitleForLocale(_ locale: Locale?) -> String {
        switch self {
        case .keystore:
            return R.string.localizable.secretTypeKeystoreSubtitle(preferredLanguages: locale?.rLanguages)
        case .seed:
            return R.string.localizable.secretTypeSeedSubtitle(preferredLanguages: locale?.rLanguages)
        case .mnemonic:
            return R.string.localizable.secretTypeMnemonicSubtitle(preferredLanguages: locale?.rLanguages)
        }
    }

    var icon: UIImage? {
        switch self {
        case .keystore:
            return R.image.iconRestoreJson()
        case .seed:
            return R.image.iconSeed()
        case .mnemonic:
            return R.image.iconMnemonic()
        }
    }
}
