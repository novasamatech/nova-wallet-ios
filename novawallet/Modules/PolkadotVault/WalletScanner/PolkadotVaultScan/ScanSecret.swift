import Foundation

extension PolkadotVaultSecret {
    struct ScanSecret {
        let secret: SecretType
        let genesisHash: Data
        let username: String?
    }
}

extension PolkadotVaultSecret.ScanSecret {
    enum SecretType {
        case seed(Data)
        case keypair(Data)
    }
}
