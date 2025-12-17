import Foundation
import Foundation_iOS
import UIKit

enum SupportCheckingFeatureType {
    case ramp(type: RampActionType, chainAsset: ChainAsset, all: [RampAction])
    case card
    case gift(chains: [ChainModel])
}

enum UnsupportedFeatureType {
    case sell
    case card
    case gift
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
            R.string(preferredLanguages: languages).localizable.commonAccount()
        case .watchOnly:
            R.string(preferredLanguages: languages).localizable.commonWatchOnly()
        case .paritySigner:
            R.string(preferredLanguages: languages).localizable.commonParitySigner()
        case .ledger, .genericLedger:
            R.string(preferredLanguages: languages).localizable.commonLedger()
        case .polkadotVault:
            R.string(preferredLanguages: languages).localizable.commonPolkadotVault()
        case .proxied:
            R.string(preferredLanguages: languages).localizable.commonProxied()
        case .multisig:
            R.string(preferredLanguages: languages).localizable.commonMultisig()
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
