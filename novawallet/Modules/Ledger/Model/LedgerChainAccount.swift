import Foundation

struct LedgerChainAccount: Equatable {
    let chain: ChainModel
    let accountId: AccountId?

    var exists: Bool { accountId != nil }

    var address: AccountAddress? {
        try? accountId?.toAddress(using: chain.chainFormat)
    }
}
