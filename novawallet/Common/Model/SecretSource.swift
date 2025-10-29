import Foundation
import UIKit

enum SecretSource: Equatable {
    enum Origin: Equatable {
        case appDefault
        case trustWallet
    }

    case mnemonic(Origin)
    case seed
    case keystore
}

extension SecretSource {
    static var chainAccountImportOptions: [SecretSource] { [.mnemonic(.appDefault), .seed, .keystore] }

    func titleForLocale(_ locale: Locale?) -> String {
        switch self {
        case .keystore:
            return R.string(preferredLanguages: locale.rLanguages).localizable.secretTypeKeystoreTitle()
        case .seed:
            return R.string(preferredLanguages: locale.rLanguages).localizable.secretTypeSeedTitle()
        case .mnemonic:
            return R.string(preferredLanguages: locale.rLanguages).localizable.secretTypeMnemonicTitle()
        }
    }

    func subtitleForLocale(_ locale: Locale?) -> String {
        switch self {
        case .keystore:
            return R.string(preferredLanguages: locale.rLanguages).localizable.secretTypeKeystoreSubtitle()
        case .seed:
            return R.string(preferredLanguages: locale.rLanguages).localizable.secretTypeSeedSubtitle()
        case .mnemonic:
            return R.string(preferredLanguages: locale.rLanguages).localizable.secretTypeMnemonicSubtitle()
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
