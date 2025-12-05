import Foundation

enum PolkadotVaultAccountScan {
    case `public`(PolkadotVaultAddressScan)
    case `private`(PolkadotVaultSecretScan)
}

struct PolkadotVaultAddressScan {
    let address: AccountAddress
    let genesisHash: Data
}

struct PolkadotVaultSecretScan {
    let secret: ScanSecret
    let genesisHash: Data
    let username: String?
}
