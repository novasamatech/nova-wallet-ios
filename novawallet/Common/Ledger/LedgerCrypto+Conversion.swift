import Foundation

extension LedgerApplication.CryptoScheme {
    var walletCryptoType: MultiassetCryptoType {
        switch self {
        case .ed25519:
            return .ed25519
        case .sr25519:
            return .sr25519
        }
    }
}
