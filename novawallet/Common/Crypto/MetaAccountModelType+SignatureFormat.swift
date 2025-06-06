import Foundation
import SubstrateSdk

extension MetaAccountModelType {
    var signaturePayloadFormat: ExtrinsicSignaturePayloadFormat {
        switch self {
        case .secrets, .watchOnly, .proxied, .multisig:
            .regular
        case .paritySigner, .polkadotVault:
            .paritySigner
        case .ledger, .genericLedger:
            .extrinsicPayload
        }
    }

    var notSupportedRawBytesSigner: NoSigningSupportType? {
        switch self {
        case .secrets, .watchOnly, .proxied, .polkadotVault:
            return nil
        case .paritySigner:
            return .paritySigner
        case .ledger, .genericLedger:
            .ledger
        case .polkadotVault:
            .polkadotVault
        case .multisig:
            .multisig
        }
    }
}
