import Foundation

extension MetaAccountModel {
    var supportsUniversalMultisig: Bool {
        guard chainAccounts.isEmpty else {
            return false
        }

        switch type {
        case .genericLedger, .ledger, .paritySigner, .proxied, .multisig:
            return false
        case .polkadotVault, .polkadotVaultRoot, .secrets, .watchOnly:
            return true
        }
    }
}

extension Array where Element == MetaAccountModel {
    func allSupportUniversalMultisig() -> Bool {
        allSatisfy(\.supportsUniversalMultisig)
    }

    func allMatchSubstrateAccount(_ accountId: AccountId) -> Bool {
        allSatisfy { $0.substrateAccountId == accountId }
    }

    func allMatchEthereumAccount(_ accountId: AccountId) -> Bool {
        allSatisfy { $0.ethereumAddress == accountId }
    }
}
