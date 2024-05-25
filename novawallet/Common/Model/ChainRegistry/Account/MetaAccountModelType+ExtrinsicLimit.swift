import Foundation

extension MetaAccountModelType {
    var maxCallsPerExtrinsic: Int? {
        switch self {
        case .ledger:
            // took min value from this https://github.com/Zondax/ledger-polkadot/blob/main/app/src/parser_txdef.h#L31
            return 5
        case .secrets, .watchOnly, .paritySigner, .polkadotVault, .proxied:
            return nil
        }
    }
}
