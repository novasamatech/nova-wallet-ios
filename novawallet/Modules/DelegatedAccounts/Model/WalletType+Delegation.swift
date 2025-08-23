import Foundation

extension MetaAccountModelType {
    var signingDelegateOrder: Int {
        switch self {
        case .secrets:
            0
        case .polkadotVault:
            1
        case .polkadotVaultRoot:
            2
        case .paritySigner:
            3
        case .genericLedger:
            4
        case .ledger:
            5
        case .proxied:
            6
        case .multisig:
            7
        case .watchOnly:
            8
        }
    }
}
