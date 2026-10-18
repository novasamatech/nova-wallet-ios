import Foundation

enum SubtensorOperationGate {
    enum Verdict: Equatable {
        case allowed
        case noSigning
        case signerNotSupported(NoSigningSupportType)
    }

    static func verdict(for walletType: MetaAccountModelType) -> Verdict {
        switch walletType {
        case .secrets, .paritySigner, .polkadotVault:
            return .allowed
        case .ledger, .genericLedger:
            return .signerNotSupported(.ledger)
        case .proxied:
            return .signerNotSupported(.proxy)
        case .multisig:
            return .signerNotSupported(.multisig)
        case .watchOnly:
            return .noSigning
        }
    }
}
