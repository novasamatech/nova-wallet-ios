import Foundation

struct LedgerChainAccount: Equatable {
    struct Info: Equatable {
        let accountId: AccountId
        let publicKey: Data
        let cryptoType: MultiassetCryptoType
    }

    let chain: ChainModel
    let info: Info?

    var accountId: AccountId? { info?.accountId }

    var address: AccountAddress? {
        try? info?.accountId.toAddress(using: chain.chainFormat)
    }

    var exists: Bool { info != nil }
}
