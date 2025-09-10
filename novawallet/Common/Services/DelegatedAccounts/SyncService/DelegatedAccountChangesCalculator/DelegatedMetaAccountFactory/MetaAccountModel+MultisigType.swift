import Foundation

extension MetaAccountModel {
    var supportsUniversalMultisig: Bool {
        guard chainAccounts.isEmpty else {
            return false
        }

        switch type {
        case .genericLedger, .ledger, .paritySigner, .proxied, .multisig:
            return false
        case .polkadotVault, .secrets, .watchOnly:
            return true
        }
    }
}

extension Array where Element == MetaAccountModel {
    func containsWalletForUniMultisig() -> Bool {
        contains { $0.supportsUniversalMultisig }
    }
}
