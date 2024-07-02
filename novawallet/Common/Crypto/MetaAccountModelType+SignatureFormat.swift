import Foundation
import SubstrateSdk

extension MetaAccountModelType {
    var signaturePayloadFormat: ExtrinsicSignaturePayloadFormat {
        switch self {
        case .secrets, .watchOnly, .proxied:
            return .regular
        case .paritySigner, .polkadotVault:
            return .paritySigner
        case .ledger, .genericLedger:
            return .extrinsicPayload
        }
    }

    var notSupportedRawBytesSigner: NoSigningSupportType? {
        switch self {
        case .secrets, .watchOnly, .proxied:
            return nil
        case .paritySigner:
            return .paritySigner
        case .ledger, .genericLedger:
            return .ledger
        case .polkadotVault:
            return .polkadotVault
        }
    }
}
