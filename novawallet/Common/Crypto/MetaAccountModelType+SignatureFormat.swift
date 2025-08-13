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
            nil
        case .paritySigner:
            .paritySigner
        case .ledger, .genericLedger:
            .ledger
        case .multisig:
            .multisig
        }
    }
}
