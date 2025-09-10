import Foundation

extension MultiassetCryptoType {
    func titleForLocale(_ locale: Locale) -> String {
        switch utilsType {
        case .sr25519:
            return R.string(preferredLanguages: locale.rLanguages).localizable.sr25519SelectionTitle()
        case .ed25519:
            return R.string(preferredLanguages: locale.rLanguages).localizable.ed25519SelectionTitle()
        case .ecdsa:
            return R.string(preferredLanguages: locale.rLanguages).localizable.ecdsaSelectionTitle()
        }
    }

    func subtitleForLocale(_ locale: Locale) -> String {
        switch utilsType {
        case .sr25519:
            return R.string(preferredLanguages: locale.rLanguages).localizable.sr25519SelectionSubtitle()
        case .ed25519:
            return R.string(preferredLanguages: locale.rLanguages).localizable.ed25519SelectionSubtitle()
        case .ecdsa:
            return R.string(preferredLanguages: locale.rLanguages).localizable.ecdsaSelectionSubtitle()
        }
    }
}
