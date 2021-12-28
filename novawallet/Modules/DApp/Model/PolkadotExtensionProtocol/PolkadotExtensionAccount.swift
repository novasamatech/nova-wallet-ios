import Foundation

struct PolkadotExtensionAccount: Encodable {
    let address: String
    let genesisHash: String?
    let name: String?
    let type: PolkadotExtensionKeypairType?
}

enum PolkadotExtensionKeypairType: String, Encodable {
    case sr25519
    case ed25519
    case ecdsa
    case ethereum

    init(cryptoType: MultiassetCryptoType) {
        switch cryptoType {
        case .sr25519:
            self = .sr25519
        case .ed25519:
            self = .ed25519
        case .substrateEcdsa:
            self = .ecdsa
        case .ethereumEcdsa:
            self = .ethereum
        }
    }
}
