import Foundation

struct SubstrateLedgerWalletModel {
    let accountId: AccountId
    let publicKey: Data
    let cryptoType: MultiassetCryptoType
    let derivationPath: Data
}
