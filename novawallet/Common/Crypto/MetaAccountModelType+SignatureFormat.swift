import Foundation
import SubstrateSdk

extension MetaAccountModelType {
    var signaturePayloadFormat: ExtrinsicSignaturePayloadFormat {
        switch self {
        case .secrets, .watchOnly:
            return .regular
        case .paritySigner, .ledger:
            return .paritySigner
        }
    }

    var supportsSigningRawBytes: Bool {
        switch self {
        case .secrets, .watchOnly, .ledger:
            return true
        case .paritySigner:
            return false
        }
    }
}
