import Foundation

extension MetaAccountModelType {
    var maxCallsPerExtrinsic: Int? {
        switch self {
        case .ledger, .genericLedger:
            // https://github.com/Zondax/ledger-polkadot/blob/main/app/src/parser_txdef.h#L28
            return 6
        case .secrets, .watchOnly, .paritySigner, .polkadotVault, .proxied, .multisig:
            return nil
        }
    }

    var delaysExtrinsicCallExecution: Bool {
        switch self {
        case .secrets, .watchOnly, .paritySigner, .ledger, .polkadotVault, .genericLedger, .proxied:
            false
        case .multisig:
            true
        }
    }
}
