import Foundation

struct PolkadotLedgerWalletModel {
    struct Substrate {
        let accountId: AccountId
        let publicKey: Data
        let cryptoType: MultiassetCryptoType
        let derivationPath: Data
    }

    struct EVM {
        let publicKey: Data
        let derivationPath: Data
    }

    let substrate: Substrate
    let evm: EVM?
}
