import Foundation

enum ParitySignerWalletFormat {
    struct Single {
        let substrateAccountId: AccountId
    }

    struct RootKeys {
        let substrate: ParitySignerWalletScan.RootPublicKey
        let ethereum: ParitySignerWalletScan.RootPublicKey
    }

    case single(Single)
    case rootKeys(RootKeys)
}
