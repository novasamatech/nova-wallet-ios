import Foundation
import SubstrateSdk

enum IntagrityProviderMessage {
    case integrityCheck(IntegrityCheckMessage)
    case signatureVerificationError(IntegritySignatureVerificationError)
}

struct IntegrityCheckMessage: Codable {
    let baseURL: String
}

struct IntegritySignatureVerificationError: Codable {
    let code: Int
    let error: String
}
