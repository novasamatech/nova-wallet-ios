import Foundation

extension LedgerCryptoScheme {
    var walletCryptoType: MultiassetCryptoType {
        switch self {
        case .ed25519:
            return .ed25519
        case .sr25519:
            return .sr25519
        case .ecdsa:
            return .substrateEcdsa
        }
    }
}
