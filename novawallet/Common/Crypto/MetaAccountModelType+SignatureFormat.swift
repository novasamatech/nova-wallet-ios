import Foundation
import SubstrateSdk

extension MetaAccountModelType {
    var signaturePayloadFormat: ExtrinsicSignaturePayloadFormat {
        switch self {
        case .secrets, .watchOnly:
            return .regular
        case .paritySigner:
            return .paritySigner
        case .ledger:
            return .extrinsicPayload
        }
    }

    var notSupportedRawBytesSigner: NoSigningSupportType? {
        switch self {
        case .secrets, .watchOnly:
            return nil
        case .paritySigner:
            return .paritySigner
        case .ledger:
            return .ledger
        }
    }
}
