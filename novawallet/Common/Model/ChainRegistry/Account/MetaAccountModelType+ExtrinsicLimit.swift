import Foundation

extension MetaAccountModelType {
    var maxCallsPerExtrinsic: Int? {
        switch self {
        case .ledger, .genericLedger:
            // https://github.com/Zondax/ledger-polkadot/blob/main/app/src/parser_txdef.h#L28
            return 6
        case .secrets, .watchOnly, .paritySigner, .polkadotVault, .polkadotVaultRoot, .proxied:
            return nil
        }
    }
}
