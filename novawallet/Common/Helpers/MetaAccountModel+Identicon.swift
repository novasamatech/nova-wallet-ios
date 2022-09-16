import Foundation

extension MetaAccountModel {
    /**
     *  Returns 32 bytes that can be used to generate identicon
     */
    func walletIdenticonData() -> Data? {
        if let substrateAccountId = substrateAccountId {
            return substrateAccountId
        }

        if let ethereumAddress = ethereumAddress {
            return ethereumAddress
        }

        return chainAccounts
            .sorted(by: { $0.accountId.lexicographicallyPrecedes($1.accountId) })
            .first?.accountId
    }
}
