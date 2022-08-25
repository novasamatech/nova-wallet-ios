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

    var supportsSigningRawBytes: Bool {
        switch self {
        case .secrets, .watchOnly:
            return true
        case .paritySigner, .ledger:
            return false
        }
    }
}
