import Foundation
import SubstrateSdk

extension MevShieldPallet {
    struct SubmitEncryptedCall: Codable {
        @BytesCodable var ciphertext: Data

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(path: MevShieldPallet.submitEncryptedPath, args: self)
        }
    }
}
