import Foundation

enum ParitySignerWalletFormat {
    struct Single {
        let accountId: AccountId
        let genesisHash: Data
        let scheme: HardwareWalletAddressScheme
        let publicKey: Data?
    }

    struct RootKeys {
        let substrate: ParitySignerWalletScan.RootPublicKey
        let ethereum: ParitySignerWalletScan.RootPublicKey
    }

    case single(Single)
    case rootKeys(RootKeys)
}
