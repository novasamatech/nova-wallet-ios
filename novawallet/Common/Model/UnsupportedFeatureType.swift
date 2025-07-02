import Foundation
import Foundation_iOS

enum SupportCheckingFeatureType {
    case sell
    case card
}

enum FeatureUnsupportedWalletType {
    case secrets
    case watchOnly
    case paritySigner
    case ledger
    case polkadotVault
    case proxied
    case genericLedger
    case multisig

    init(walletType: MetaAccountModelType) {
        switch walletType {
        case .secrets:
            self = .secrets
        case .watchOnly:
            self = .watchOnly
        case .paritySigner:
            self = .paritySigner
        case .ledger:
            self = .ledger
        case .polkadotVault:
            self = .polkadotVault
        case .proxied:
            self = .proxied
        case .genericLedger:
            self = .genericLedger
        case .multisig:
            self = .multisig
        }
    }

    func description(for locale: Locale) -> String {
        let languages = locale.rLanguages

        return switch self {
        case .secrets:
            R.string.localizable.commonAccount(preferredLanguages: languages)
        case .watchOnly:
            R.string.localizable.commonWatchOnly(preferredLanguages: languages)
        case .paritySigner:
            R.string.localizable.commonParitySigner(preferredLanguages: languages)
        case .ledger, .genericLedger:
            R.string.localizable.commonLedger(preferredLanguages: languages)
        case .polkadotVault:
            R.string.localizable.commonPolkadotVault(preferredLanguages: languages)
        case .proxied:
            R.string.localizable.commonProxied(preferredLanguages: languages)
        case .multisig:
            R.string.localizable.commonMultisig(preferredLanguages: languages)
        }
    }

    func sheetImage() -> UIImage? {
        switch self {
        case .paritySigner:
            R.image.iconParitySignerInSheet()
        case .polkadotVault:
            R.image.iconPolkadotVaultInSheet()
        case .ledger, .genericLedger:
            R.image.iconLedgerInSheet()
        case .proxied:
            R.image.imageProxy()
        case .multisig:
            R.image.imageMultisig()
        case .watchOnly:
            R.image.imageNoKeys()
        case .secrets:
            nil
        }
    }
}
