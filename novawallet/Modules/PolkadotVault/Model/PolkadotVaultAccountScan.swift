import Foundation

enum PolkadotVaultAccount {
    case `public`(PolkadotVaultAddress)
    case `private`(address: AccountAddress, secret: PolkadotVaultSecret)

    var genesisHash: Data {
        switch self {
        case let .public(scan): scan.genesisHash
        case let .private(_, scan): scan.genesisHash
        }
    }

    var address: AccountAddress {
        switch self {
        case let .public(scan): scan.address
        case let .private(address, _): address
        }
    }
}

struct PolkadotVaultAddress {
    let address: AccountAddress
    let genesisHash: Data
}

struct PolkadotVaultSecret {
    let secret: SecretType
    let genesisHash: Data
    let username: String?
}

extension PolkadotVaultSecret {
    enum SecretType {
        case seed(Data)
        case keypair(publicKey: Data, secretKey: Data)
    }
}
