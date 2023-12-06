import Foundation
import SubstrateSdk

extension MetaAccountModelType {
    var signaturePayloadFormat: ExtrinsicSignaturePayloadFormat {
        switch self {
        case .secrets, .watchOnly, .proxy:
            return .regular
        case .paritySigner, .polkadotVault:
            return .paritySigner
        case .ledger:
            return .extrinsicPayload
        }
    }

    var notSupportedRawBytesSigner: NoSigningSupportType? {
        switch self {
        case .secrets, .watchOnly, .proxy:
            return nil
        case .paritySigner:
            return .paritySigner
        case .ledger:
            return .ledger
        case .polkadotVault:
            return .polkadotVault
        }
    }
}
