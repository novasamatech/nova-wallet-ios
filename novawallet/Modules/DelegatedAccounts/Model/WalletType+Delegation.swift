import Foundation

extension MetaAccountModelType {
    var signingDelegateOrder: Int {
        switch self {
        case .secrets:
            0
        case .polkadotVault:
            1
        case .paritySigner:
            2
        case .genericLedger:
            3
        case .ledger:
            4
        case .proxied:
            5
        case .multisig:
            6
        case .watchOnly:
            7
        }
    }
}
